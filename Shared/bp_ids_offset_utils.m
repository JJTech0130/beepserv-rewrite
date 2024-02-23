#include "./dylibify/obj-c/dylibify.h"
#import <substrate.h>
#import "bp_ids_offset_utils.h"
// I guess we can still log this as if it's in identityservicesd
#import "../IdentityServices/Logging.h"

// A weird offset finder for nac_init, nac_key_establishment, nac_sign.
// It only works on arm64(e) because it looks for / parses instruction parts.
// Not every version / device is supported yet.
//
// How it works:
// 1. Find the string "Calling NACInit with"
// 2. Find the reference to the string in code
// 3. Find the call to nac_init shortly after the reference
// 4. Find the other two functions by looking through the beginning
//    of the page where nac_init is located

intptr_t bp_nac_init_func_offset = 0;
intptr_t bp_nac_key_establishment_func_offset = 0;
intptr_t bp_nac_sign_func_offset = 0;

NSString * __nonnull patched_ids_path() {
    NSString *dir_paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    return [NSString stringWithFormat:@"%@/patched_identityservicesd.dylib", dir_paths];
}

NSString * __nonnull dylibify_ids_if_needed(NSError * __nullable * __nullable err) {
    NSString *patched_path = patched_ids_path();

    if ([NSFileManager.defaultManager fileExistsAtPath:patched_path])
        return patched_path;

    dylibify(identityservicesd_path, patched_path, err);
    return patched_path;
}

unsigned long bp_get_image_file_size(NSError * __nullable * __nullable error, NSString * __nonnull path) {
    #define ERR(...) RET_ERR(error, 0, __VA_ARGS__)

    NSURL *image_file_url = [NSURL fileURLWithPath:path];

    NSNumber *image_file_size;
    NSError *image_file_size_retrieval_error;

    [image_file_url
        getResourceValue: &image_file_size
        forKey: NSURLFileSizeKey
        error: &image_file_size_retrieval_error
    ];

    if (image_file_size_retrieval_error)
        ERR(@"Couldn't read size for %@: %@", path, image_file_size_retrieval_error)

    return image_file_size.longValue;

    #undef ERR
}

unsigned long cached_patched_image_file_size;
unsigned long bp_get_patched_ids_image_file_size(NSError * __nullable * __nullable error) {
    #define ERR(...) RET_ERR(error, 0, __VA_ARGS__)

    NSError *dylibify_err;
    NSString *path = dylibify_ids_if_needed(&dylibify_err);

    if (dylibify_err)
        ERR(@"Couldn't dylibify ids: %@", dylibify_err);

    cached_patched_image_file_size = bp_get_image_file_size(error, path);
    return cached_patched_image_file_size;

    #undef ERR
}

// this doesn't need to take a path as an argument b/c whatever image you're calling it from
// should have already loaded identityservicesd into memory (either by being identityservicesd
// or through dlopen'ing the patched version)
intptr_t bp_cached_ref_addr = 0;
intptr_t bp_get_ref_addr() {
    // e.g. when using palera1n with ellekit, the first dyld image
    // is libinjector.dylib so if that is the case we need to
    // try using the second dyld image, etc.

    if (bp_cached_ref_addr)
        return bp_cached_ref_addr;

    uint32_t img_count = _dyld_image_count();
    for (int i = 0; i < img_count; i += 1) {
        const char* image_name = _dyld_get_image_name(i);
        if (!image_name) { continue; }
        NSString* image_name_string = [[NSString alloc] initWithCString: image_name encoding: NSUTF8StringEncoding];

        if ([image_name_string containsString: @"identityservicesd"]) {
            bp_cached_ref_addr = _dyld_get_image_vmaddr_slide(i) + 0x100000000;
            return bp_cached_ref_addr;
        }
    }

    return 0;
}

intptr_t bp_find_pattern_offset(
    const char* pattern,
    int pattern_length,
    int target_match_index,
    intptr_t start_offset,
    intptr_t max_offset_from_start_offset,
    unsigned long image_size
) {
    intptr_t ref_addr = bp_get_ref_addr();

    intptr_t current_start_addr = ref_addr;

    if (start_offset) {
        current_start_addr += start_offset;
    } else {
        current_start_addr += 0x000000004;
    }

    unsigned long search_limit = image_size - 200;

    intptr_t max_addr = start_offset + max_offset_from_start_offset;

    if (max_offset_from_start_offset && max_addr <= search_limit) {
        search_limit = max_addr;
    }

    int match_count = 0;

    for (int i = start_offset; i < search_limit; i += 1) {
        char value_at_start_addr = *((char*) current_start_addr);

        if (value_at_start_addr == pattern[0]) {
            bool has_failed = false;

            for (int current_pattern_index = 1; current_pattern_index < pattern_length; current_pattern_index += 1) {
                char value_at_current_pattern_addr = *((char*) (current_start_addr + current_pattern_index));

                if (value_at_current_pattern_addr != pattern[current_pattern_index]) {
                    has_failed = true;
                    break;
                }
            }

            if (!has_failed) {
                if (target_match_index == match_count) {
                    intptr_t offset_addr = current_start_addr - ref_addr;

                    return offset_addr;
                } else {
                    match_count += 1;
                }
            }
        }

        current_start_addr += 1;
    }

    return 0;
}

intptr_t bp_find_nac_init_call_log_string(unsigned long image_size) {
    NSString *nac_init_call_log_string_content = @"Calling NACInit with";

    intptr_t niclsc_offset = bp_find_pattern_offset(
        nac_init_call_log_string_content.UTF8String,
        nac_init_call_log_string_content.length,
        0,
        0,
        0,
        image_size
    );

    return niclsc_offset;
}

// Returns the offset to the 'add' instruction, see explanation below
intptr_t bp_find_nac_init_call_log_string_caller(
    intptr_t niclsc_offset, /* e.g. 0xa471bb */
    unsigned long image_size
) {
    // The nac init log string is loaded by
    // 1. Getting a pointer to the page via 'adrp'
    // 2. 'add'ing the offset from the page to the string
    //
    // Since 'adrp' is relative to the caller address,
    // we look for the 'add' instruction and make sure it
    // is preceded by the correct 'adrp' instruction to avoid
    // false-positives

    intptr_t niclsc_offset_from_page = niclsc_offset & 0x000FFF; // e.g. 0x1bb
    intptr_t niclsc_offset_from_page_part1 = (niclsc_offset_from_page & 0b000000111111) << 2;
    intptr_t niclsc_offset_from_page_part2 = (niclsc_offset_from_page & 0b111111000000) >> 6;

    int pattern_length = 4;
    char pattern[4] = { 0x63, niclsc_offset_from_page_part1, niclsc_offset_from_page_part2, 0x91 };

    intptr_t offset_to_niclsc_page = niclsc_offset - niclsc_offset_from_page;

    intptr_t prev_potential_caller_offset = 0;

    for (int i = 0; i < 20; i += 1) {
        intptr_t potential_caller_offset = bp_find_pattern_offset(
            pattern,
            pattern_length,
            0,
            prev_potential_caller_offset + 1,
            0,
            image_size
        );

        if (!potential_caller_offset) {
            continue;
        }

        prev_potential_caller_offset = potential_caller_offset;

        intptr_t previous_instruction_offset = potential_caller_offset - 4;

        intptr_t previous_instruction_addr = bp_get_ref_addr() + previous_instruction_offset;

        unsigned char previous_instruction_a = *((char*) previous_instruction_addr);
        unsigned char previous_instruction_b = *((char*) previous_instruction_addr + 1);
        unsigned char previous_instruction_c = *((char*) previous_instruction_addr + 2);
        unsigned char previous_instruction_d = *((char*) previous_instruction_addr + 3);

        if (previous_instruction_c != 0) {
            continue;
        }

        intptr_t adrp_value_a = previous_instruction_b << 5;
        intptr_t adrp_value_b = (previous_instruction_a & 0b11100000) >> 3;
        intptr_t adrp_value_c = (previous_instruction_d & 0b01100000) >> 5;

        intptr_t adrp_value = (adrp_value_a + adrp_value_b + adrp_value_c) << 12;

        intptr_t adrp_result_value = (previous_instruction_offset + adrp_value)  & 0xFFF000;

        if (adrp_result_value == offset_to_niclsc_page) {
            return potential_caller_offset;
        }
    }

    return 0;
}

intptr_t bp_find_nac_init_call(
    intptr_t niclsc_caller_offset,
    unsigned long image_size
) {
    // Look for the next 'e4 ?? ?? 91' after the
    // caller offset as that seems to be the instruction before the 'bl' that calls nac_init
    // and there don't seem to be any false-positives in-between as far as I can tell

    int pattern_length = 1;
    char pattern[1] = { 0xe4 };

    intptr_t prev_potential_call_pre_offset = niclsc_caller_offset;

    for (int i = 0; i < 20; i += 1) {
        intptr_t potential_call_pre_offset = bp_find_pattern_offset(
            pattern,
            pattern_length,
            0,
            prev_potential_call_pre_offset + 1,
            0,
            image_size
        );

        if (!potential_call_pre_offset) {
            return 0;
        }

        prev_potential_call_pre_offset = potential_call_pre_offset;

        intptr_t potential_call_pre_instruction_d_addr = bp_get_ref_addr() + potential_call_pre_offset + 3;

        unsigned char potential_call_pre_instruction_d = *((char*) potential_call_pre_instruction_d_addr);

        if (potential_call_pre_instruction_d == 0x91) {
            intptr_t nac_init_call_offset = potential_call_pre_offset + 4;

            return nac_init_call_offset;
        }
    }

    return 0;
}

intptr_t bp_convert_nac_init_call_offset_to_nac_init_func_offset(intptr_t nac_init_call_offset) {
    intptr_t nac_init_call_addr = bp_get_ref_addr() + nac_init_call_offset;

    unsigned char nac_init_call_instruction_a = *((char*) nac_init_call_addr);
    unsigned char nac_init_call_instruction_b = *((char*) nac_init_call_addr + 1);
    unsigned char nac_init_call_instruction_c = *((char*) nac_init_call_addr + 2);

    intptr_t nac_init_call_instruction_value_a = nac_init_call_instruction_a;
    intptr_t nac_init_call_instruction_value_b = nac_init_call_instruction_b << 8;
    intptr_t nac_init_call_instruction_value_c = nac_init_call_instruction_c << 16;
    intptr_t nac_init_call_instruction_value = (nac_init_call_instruction_value_a + nac_init_call_instruction_value_b + nac_init_call_instruction_value_c) << 2;

    intptr_t nac_init_func_offset = nac_init_call_offset + nac_init_call_instruction_value;

    return nac_init_func_offset;
}

// Returns 1 if nac_key_establishment and 2 if nac_sign
int bp_check_if_func_is_nac_sign_or_nac_key_establishment(
    intptr_t func_offset,
    unsigned long image_size
) {
    int match_count = 0;

    // We look for instructions like this: ?? 03 ?? aa
    // These are 'mov' instructions and should exist 3 times
    // a bit after the start of nac_key_establishment
    // and 5 times after the start of nac_sign

    int pattern_length = 1;
    char pattern[1] = { 0xaa };

    for (int i = 0; i < 1000; i += 1) {
        intptr_t match_offset = bp_find_pattern_offset(
            pattern,
            pattern_length,
            i,
            func_offset,
            40 * 4, /* 40 instructions max */
            image_size
        );

        if (!match_offset) {
            break;
        }

        intptr_t match_instruction_b_offset = match_offset - 2;

        unsigned char match_instruction_b = *((char*) (bp_get_ref_addr() + match_instruction_b_offset));

        if (match_instruction_b != 0x03) {
            continue;
        }

        match_count += 1;
    }

    if (match_count < 3 || match_count > 6) {
        return 0; // unknown
    } else if (match_count < 5) {
        return 1; // nac_key_establishment
    } else {
        return 2; // nac_sign
    }
}

void bp_find_offsets(
    NSError * __nullable * __nullable error,
    NSString * __nonnull identityservicesd_path
) {
    #define ERR(...) RET_ERR(error, , __VA_ARGS__)

    NSError *size_err;
    int image_size = bp_get_image_file_size(&size_err, identityservicesd_path);
    if (!image_size || size_err)
        ERR(@"Couldn't get image file size: %@", size_err);

    intptr_t ref_addr = bp_get_ref_addr();
    if (!ref_addr)
        ERR(@"Couldn't get ref_addr");

    if (ref_addr == 0x100000000)
        ERR(@"ref_addr == 0x100000000, not continuing");

    intptr_t niclsc_offset = bp_find_nac_init_call_log_string(image_size);

    if (!niclsc_offset)
        ERR(@"Couldn't get nac_init_call_log_string");

    intptr_t niclsc_caller_offset = bp_find_nac_init_call_log_string_caller(niclsc_offset, image_size);

    if (!niclsc_caller_offset)
        ERR(@"Couldn't get caller before nac init log string");

    intptr_t nac_init_call_offset = bp_find_nac_init_call(niclsc_caller_offset, image_size);

    if (!nac_init_call_offset)
        ERR(@"Couldn't find call offset for nac_init_call");

    bp_nac_init_func_offset = bp_convert_nac_init_call_offset_to_nac_init_func_offset(nac_init_call_offset);

    LOG(@"nac_init offset: %p", ((void*) bp_nac_init_func_offset));

    if (bp_nac_init_func_offset <= 0)
        ERR(@"nac_init_func_offset is negative (%lu)", bp_nac_init_func_offset);

    if (bp_nac_init_func_offset >= image_size)
        ERR(@"nac_init_func_offset (%lx) is outside the bounds of the file size (%x)", bp_nac_init_func_offset, image_size);

    intptr_t nac_init_func_approx_offset = bp_nac_init_func_offset & 0xFFFF00;

    intptr_t nac_init_func_offset_from_page = bp_nac_init_func_offset & 0xFFF000;

    // A pattern that should exist in every potential function
    int pattern_length = 3;
    char pattern[3] = { 0xd1, 0xfc, 0x6f };

    // On my test devices, the nac functions are the first 3 results when looking for this pattern
    // from the page offset, so I'm gonna assume this is always the case, this may need to be changed
    // if this turns out to not always be the case
    for (int i = 0; i < 20; i += 1) {
        // We're looking for a pattern beginning with the 4th byte of the first instruction of the function
        // so we substract 3 to get to the start
        intptr_t match_offset = bp_find_pattern_offset(
            pattern,
            pattern_length,
            i,
            nac_init_func_offset_from_page,
            0,
            image_size
        ) - 3;

        if (match_offset <= 0)
            ERR(@"match_offset <= 0 (== %lx) at iteration %d", match_offset, i);

        // On arm64e, we have to go back another instruction to get to the beginning of
        // the function because there's a 'pacibsp' instruction
        #if __arm64e__
        match_offset -= 4;
        #endif

        intptr_t match_approx_offset = match_offset & 0xFFFF00;

        if (match_approx_offset == nac_init_func_approx_offset) {
            continue;
        }

        // This pattern should always be there as part of a 'cmp'
        // instruction, so make sure we're not chasing ghosts
        int second_pattern_length = 2;
        char second_pattern[2] = { 0x00, 0xf1 };

        intptr_t second_match_offset = bp_find_pattern_offset(
            second_pattern,
            second_pattern_length,
            0,
            match_offset,
            30 * 4, /* 30 instructions max */
            image_size
        );

        if (!second_match_offset) {
            continue;
        }

        int check_result = bp_check_if_func_is_nac_sign_or_nac_key_establishment(match_offset, image_size);

        if (check_result == 1) {
            if (!bp_nac_key_establishment_func_offset) {
                bp_nac_key_establishment_func_offset = match_offset;
                LOG(@"nac_key_establishment offset: %p", ((void*) bp_nac_key_establishment_func_offset));
            } else {
                LOG(@"Other candidate for nac_key_establishment at offset: %p", ((void*) match_offset));
            }
        } else if (check_result == 2) {
            if (!bp_nac_sign_func_offset) {
                bp_nac_sign_func_offset = match_offset;
                LOG(@"nac_sign offset: %p", ((void*) bp_nac_sign_func_offset));
            } else {
                LOG(@"Other candidate for nac_sign at offset: %p", ((void*) match_offset));
            }
        }

        if (bp_nac_key_establishment_func_offset && bp_nac_sign_func_offset) {
            // we got it :)
            return;
        }
    }

    ERR(@"Iterations yielded no valid candidates for fns")
}

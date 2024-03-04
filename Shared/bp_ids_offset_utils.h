#ifndef BP_IDS_OFFSET_UTILS_H
#define BP_IDS_OFFSET_UTILS_H

#import <Foundation/Foundation.h>
#import <mach-o/dyld.h>
#import <dlfcn.h>

// for use in many places
#define RET_ERR(err, def_return, ...) { \
    LOG(__VA_ARGS__); \
    NSString *err_str = [NSString stringWithFormat:__VA_ARGS__]; \
    if (err) \
        *err = [NSError errorWithDomain:@"beepserv" code:1 userInfo:@{@"Error Reason": err_str}]; \
    return def_return; \
}

extern intptr_t bp_nac_init_func_offset;
extern intptr_t bp_nac_key_establishment_func_offset;
extern intptr_t bp_nac_sign_func_offset;

typedef int nac_init_fn(const void * __nonnull, int, void * __nullable * __nonnull, void * __nullable * __nonnull, int * __nonnull);
typedef int nac_key_establishment_fn(void * __nonnull, const void * __nonnull, int);
typedef int nac_sign_fn(void * __nonnull, void * __nullable, int, void * __nullable * __nonnull, int * __nonnull);

static NSString * __nonnull identityservicesd_path = @"/System/Library/PrivateFrameworks/IDS.framework/identityservicesd.app/identityservicesd";

NSString * __nonnull setup_ids_framework_if_needed();
NSString * __nonnull force_dylibify_ids(NSError * __nullable * __nullable);
NSString * __nonnull dylibify_ids_if_needed(NSError * __nullable * __nullable);
unsigned long bp_get_image_file_size(NSError * __nullable * __nullable error, NSString * __nonnull path);
void bp_find_offsets_within_buffer(NSError * __nullable * __nullable error, intptr_t ref_addr, unsigned long image_size);
void bp_find_offsets(NSError * __nullable * __nullable, NSString * __nonnull);

intptr_t bp_get_ref_addr();

#endif

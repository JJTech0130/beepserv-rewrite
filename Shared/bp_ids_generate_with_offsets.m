#include "../Controller/Logging.h"
#include "bp_ids_offset_utils.h"
#include <Foundation/Foundation.h>
#include <errno.h>
#include <stdio.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>
#include <pthread.h>

bool bp_has_found_offsets = false;

/*FILE *ids_file;
void *identityservicesd_start = MAP_FAILED;
size_t identityservicesd_len = 0;*/

void *ids_handle;

NSData * __nullable validation_data_from_offsets(NSError * __nullable * __nullable error) {
    #define ERR(...) RET_ERR(error, nil, __VA_ARGS__)

    NSError *dylibify_err;
    NSString *patched_path = dylibify_ids_if_needed(&dylibify_err);

    if (dylibify_err)
        ERR(@"Couldn't dylibify identityservicesd: %@", dylibify_err);

    // `dlopen` can run into issues sometimes, so here's code to mmap it into memory
    // instead if necessary
    /*int fd;
    if (identityservicesd_start == MAP_FAILED || !identityservicesd_len) {

        NSError *size_err;
        identityservicesd_len = bp_get_image_file_size(&size_err, patched_path);

        if (size_err)
            ERR(@"Couldn't get file size of patched identityservicesd: %@", size_err);

        if (ids_file)
            fclose(ids_file);

        ids_file = fopen(patched_path.UTF8String, "r");

        if (!ids_file)
            ERR(@"Couldn't fopen identityservicesd: %d", errno);

        fd = fileno(ids_file);
        if (!fd)
            ERR(@"Couldn't get fd for ids_file");

        identityservicesd_start = mmap(
            NULL,
            identityservicesd_len,
            PROT_READ,
            MAP_FILE | MAP_PRIVATE,
            fd,
            0
        );

        if (identityservicesd_start == MAP_FAILED)
            ERR(@"Couldn't mmap identityservicesd read: %d, %s", errno, strerror(errno));

        // so we should be making sure to `fclose` and `munmap` the resources we create
        // during this little block but they should be alive for the lifetime of the program
        // so it's kinda like whatever
    }*/

    if (!ids_handle) {
        ids_handle = dlopen(patched_path.UTF8String, RTLD_LAZY | RTLD_GLOBAL);

        if (!ids_handle)
            ERR(@"Couldn't dlopen identityservicesd: %s", dlerror());
    }

    if (!bp_has_found_offsets) {
        NSError *file_err;
        unsigned long identityservicesd_len = bp_get_image_file_size(&file_err, patched_path);

        if (file_err)
            ERR(@"Couldn't get size of patched identityservicesd: %@", file_err);

        intptr_t identityservicesd_start = bp_get_ref_addr();

        NSError *offset_err;
        bp_find_offsets_within_buffer(&offset_err, (intptr_t)identityservicesd_start, identityservicesd_len);

        if (offset_err)
            ERR(@"Couldn't find offsets to use: %@", offset_err);

        bp_has_found_offsets = true;
    }

    /*if (mprotect(identityservicesd_start, identityservicesd_len, PROT_EXEC) != 0)
        ERR(@"mprotect returned error code %d: %s", errno, strerror(errno));*/

    intptr_t ref_addr = bp_get_ref_addr();
    // intptr_t ref_addr = (intptr_t)identityservicesd_start;

    nac_init_fn *nac_init = (nac_init_fn *)(bp_nac_init_func_offset + ref_addr);
    nac_key_establishment_fn *nac_key_establishment = (nac_key_establishment_fn *)(bp_nac_key_establishment_func_offset + ref_addr);
    nac_sign_fn *nac_sign = (nac_sign_fn *)(bp_nac_sign_func_offset + ref_addr);

    NSDictionary *cert_dict;
    NSURL *cert_url = [NSURL URLWithString:@"http://static.ess.apple.com/identity/validation/cert-1.0.plist"];
    if (@available(iOS 11, *)) {
        cert_dict = [NSDictionary dictionaryWithContentsOfURL:cert_url error:error];
        if (error && *error)
            ERR(@"Retrieving apple cert returned an error: %@", *error);
    } else {
        cert_dict = [NSDictionary dictionaryWithContentsOfURL:cert_url];
    }

    NSData *cert = cert_dict[@"cert"];
    if (!cert)
        ERR(@"cert_dict did not contain needed `cert` k/v: %@", cert_dict);

    void *validation_ctx;
    void *init_output_bytes;
    int init_output_len;

    int resp = nac_init(cert.bytes, cert.length, &validation_ctx, &init_output_bytes, &init_output_len);
    if (resp != 0)
        ERR(@"NACInit returned error code %d", resp);

    NSData *output_data = [NSData dataWithBytesNoCopy:init_output_bytes length:init_output_len];

    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://identity.ess.apple.com/WebObjects/TDIdentityService.woa/wa/initializeValidation"]];
    [req setHTTPMethod:@"POST"];
    [req setValue:@"application/x-apple-plist" forHTTPHeaderField:@"Content-Type"];

    NSDictionary *messageBody = @{
        @"session-info-request": output_data
    };

    [req setHTTPBody:[NSPropertyListSerialization dataWithPropertyList:messageBody
                                                                format:NSPropertyListXMLFormat_v1_0
                                                               options:0
                                                                 error:nil]];

    __block NSError *outerReqError;
    __block NSData *sessionInfo;
    dispatch_semaphore_t taskSignal = dispatch_semaphore_create(0);
    NSURLSessionDataTask *task = [NSURLSession.sharedSession dataTaskWithRequest:req completionHandler:^(NSData *plistData, NSURLResponse *response, NSError *req_error){
        if (req_error) {
            outerReqError = [NSError errorWithDomain:@"beepserv" code:1 userInfo:@{@"Error Reason": [NSString stringWithFormat:@"initializeValidation request failed: %@", req_error]}];
        } else {
            NSDictionary* plist = [NSPropertyListSerialization propertyListWithData:plistData options:0 format:NULL error:&outerReqError];
            LOG(@"Whole dict is %@", plist);
            sessionInfo = plist[@"session-info"];
        }

        dispatch_semaphore_signal(taskSignal);
    }];

    [task resume];

    dispatch_semaphore_wait(taskSignal, DISPATCH_TIME_FOREVER);

    if (outerReqError) {
        if (error) *error = outerReqError;
        return nil;
    }

    if (!sessionInfo)
        ERR(@"initializeValidation request didn't contain session-info");

    LOG(@"Got sessionInfo %@", sessionInfo);

    int key_establishment_resp = nac_key_establishment(validation_ctx, sessionInfo.bytes, sessionInfo.length);

    if (key_establishment_resp != 0)
        ERR(@"nac_key_establishment returned error code %d", key_establishment_resp);

    void *sign_output_bytes;
    int sign_output_len;
    int nac_sign_resp = nac_sign(validation_ctx, nil, 0, &sign_output_bytes, &sign_output_len);

    if (nac_sign_resp != 0)
        ERR(@"nac_sign returned error code %d", nac_sign_resp);

    NSData *validationData = [NSData dataWithBytesNoCopy:sign_output_bytes length:sign_output_len];
    return validationData;
}

#import "Tweak.h"
#import "../Shared/bp_ids_offset_utils.h"
#import "./bp_ids_hooking_utils.h"
#import "./bp_ids_fallback.h"
#import "./Logging.h"
#import "../Shared/NSDistributedNotificationCenter.h"
#import "../Shared/BPTimer.h"

bool bp_has_found_offsets = false;
bool bp_is_using_fallback_method = false;

// Timer that fires if validation data has not been retrieved via
// the newer method after a certain amount of time
// so we can try again using the fallback method
BPTimer* bp_validation_data_retrieval_using_newer_method_timer = nil;

void bp_handle_validation_data(NSData* validationData, bool isFallbackMethod) {
    if (bp_validation_data_retrieval_using_newer_method_timer) {
        [bp_validation_data_retrieval_using_newer_method_timer invalidate];
        bp_validation_data_retrieval_using_newer_method_timer = nil;
    }

    double validationDataExpiryTimestamp;

    if (isFallbackMethod) {
        // Validation data should expire after 10 minutes
        validationDataExpiryTimestamp = [NSDate.date timeIntervalSince1970] + (10 * 60);
    } else {
        // Let's get fresh data after 30 seconds because why not
        validationDataExpiryTimestamp = [NSDate.date timeIntervalSince1970] + 30;
    }

    // Send validation data to the Controller
    // which then sends it to the relay
    [NSDistributedNotificationCenter.defaultCenter
        postNotificationName: kNotificationValidationDataResponse
        object: nil
        userInfo: @{
            kValidationData: validationData,
            kValidationDataExpiryTimestamp: [NSNumber numberWithDouble: validationDataExpiryTimestamp]
        }
    ];
}

@interface IDSValidationQueue: NSObject
    - (void) _sendAbsintheValidationCertRequestIfNeededForSubsystem:(long long)arg1;
@end

@interface IDSRegistrationCenter: NSObject
    + (instancetype) sharedInstance;

    // not in iOS 15+ (afaik)
    - (void) _sendAbsintheValidationCertRequestIfNeeded;

    // only in iOS 15+ (afaik)
    - (IDSValidationQueue*) validationQueue;
@end

// This should eventually lead to nac_key_establishment being called
bool bp_send_cert_request_if_needed() {
    IDSRegistrationCenter* registrationCenter = [%c(IDSRegistrationCenter) sharedInstance];

    if ([registrationCenter respondsToSelector: @selector(_sendAbsintheValidationCertRequestIfNeeded)]) {
        [[%c(IDSRegistrationCenter) sharedInstance]
            _sendAbsintheValidationCertRequestIfNeeded
        ];
    } else if ([registrationCenter respondsToSelector: @selector(validationQueue)]) {
        IDSValidationQueue* validationQueue = [registrationCenter validationQueue];

        if ([validationQueue respondsToSelector: @selector(_sendAbsintheValidationCertRequestIfNeededForSubsystem:)]) {
            [validationQueue _sendAbsintheValidationCertRequestIfNeededForSubsystem: 1];
        } else {
            return false;
        }
    } else {
        return false;
    }

    return true;
}

void bp_start_validation_data_request() {
    if (bp_has_found_offsets) {
        bool was_sending_cert_request_successful = bp_send_cert_request_if_needed();

        if (was_sending_cert_request_successful) {
            bp_validation_data_retrieval_using_newer_method_timer = [BPTimer
                scheduleTimerWithTimeInterval: 8
                completion: ^{
                    // Assume that the newer method of validation data
                    // retrieval / generation does not currently work on this
                    // device and try again

                    bp_has_found_offsets = false;
                    bp_start_validation_data_request();
                }
            ];

            return;
        }
    }

    bp_is_using_fallback_method = true;

    NSError* fallback_error = bp_start_fallback_validation_data_request();

    if (fallback_error) {
        // Notify the Controller about the error
        [NSDistributedNotificationCenter.defaultCenter
            postNotificationName: kNotificationValidationDataResponse
            object: nil
            userInfo: @{
                kError: [NSError errorWithDomain:kSuiteName code: 0 userInfo: @{
                    @"Error Reason": @"No account found"
                }]
            }
        ];
    }
}

%ctor {
    LOG(@"Started");

    // Wait a bit to make sure we don't break things
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        LOG(@"Finding offsets");

        NSError *offset_err;
        bp_find_offsets(&offset_err, identityservicesd_path);
        bp_has_found_offsets = offset_err != nil;

        if (offset_err) {
            LOG(@"Finding offsets failed: %@", offset_err);

            bp_is_using_fallback_method = true;
        } else {
            LOG(@"Found offsets");

            bp_setup_hooks();
        }

        // Listen for validation data requests from
        // the Controller (which listens for requests from the relay)
        [NSDistributedNotificationCenter.defaultCenter
            addObserverForName: (NSString*) kNotificationRequestValidationData
            object: nil
            queue: NSOperationQueue.mainQueue
            usingBlock: ^(NSNotification* notification)
        {
            LOG(@"Received request for validation data");

            // Notify the Controller that we have received the request
            [NSDistributedNotificationCenter.defaultCenter
                postNotificationName: kNotificationRequestValidationDataAcknowledgement
                object: nil
                userInfo: nil
            ];

            bp_start_validation_data_request();
        }];
    });
}

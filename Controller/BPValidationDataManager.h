#import <Foundation/Foundation.h>
#import "BPTimer.h"

@interface BPValidationDataManager: NSObject
    @property (retain) NSData* cachedValidationData;
    @property double cachedValidationDataExpiryTimestamp;
    // Timer that fires if we have sent a request for validation data
    // and not received an acknowledgement in a specific amount of time.
    // This lets us know if something is wrong with the
    // identityservicesd tweak
    @property (retain) BPTimer* validationDataRequestAcknowledgementTimer;
    
    + (instancetype) sharedInstance;
    
    // Called when we receive a response from IdentityServices
    - (void) handleResponseWithValidationData:(NSData*)validationData validationDataExpiryTimestamp:(double)validationDataExpiryTimestamp error:(NSError*)error;
    
    // Sends a request for validation data to IdentityService
    - (void) request;
    
    // Returns the cached validation data if it exists and it is still valid
    - (NSData*) getCachedIfPossible;
    
    - (void) handleValidationDataRequestAcknowledgement;
    - (void) handleValidationDataRequestDidNotReceiveAcknowledgement;
@end
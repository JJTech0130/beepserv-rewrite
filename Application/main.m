#import <Foundation/Foundation.h>
#import "BPAppDelegate.h"
#import "./Logging.h"
#import "../Shared/bp_ids_generate_with_offsets.h"

int main(int argc, char* argv[]) {
    if (argc > 1 && strcmp(argv[1], "get-validation-data") == 0) {
        NSError *err;
        NSData *data = validation_data_from_offsets(&err);
        if (err) {
            fprintf(stderr, "Couldn't get validation data from within spawned root binary: %s\n", err.description.UTF8String);
            return 1;
        } else {
            // we use stderr here so that normal logging calls to printf aren't included
            fprintf(stderr, "%s", [data base64EncodedStringWithOptions:0].UTF8String);
            return 0;
        }
    }

    @autoreleasepool {
        LOG(@"Started");
        return UIApplicationMain(argc, argv, nil, NSStringFromClass(BPAppDelegate.class));
    }
}

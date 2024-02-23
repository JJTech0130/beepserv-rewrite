#import "./BPPrefs.h"
#import "./Constants.h"

// Because this file is shared between modules, we cannot use the
// module-specific logging files
#import "./Constants.h"
#define LOG(...) bp_log_impl(@"Shared", [NSString stringWithFormat: __VA_ARGS__])
void bp_log_impl(NSString* moduleName, NSString* logString);

@implementation BPPrefs
    + (NSURL * __nonnull)prefsUrl {
        return [NSURL URLWithString: [NSString stringWithFormat: @"file://%@", kPrefsFilePath]];
    }

    + (NSDictionary * __nonnull)getCurrentPrefs {
        NSURL* url = [self prefsUrl];

        NSDictionary* prefsDict;

        if (@available(iOS 11, *)) {
            prefsDict = [NSDictionary dictionaryWithContentsOfURL: url error: nil];
        } else {
            prefsDict = [NSDictionary dictionaryWithContentsOfURL: url];
        }

        return prefsDict ?: NSDictionary.new;
    }

    + (NSNumber * __nullable) getBoolForKey:(const NSString * __nonnull)key {
        return [self getCurrentPrefs][key];
    }

    + (void) setBool:(BOOL)value forKey:(const NSString * __nonnull)key {
        NSMutableDictionary *prefsDict = [self getCurrentPrefs].mutableCopy;
        prefsDict[key] = [NSNumber numberWithBool:value];

        NSError *writingError;
        NSURL *url = [self prefsUrl];

        if (@available(iOS 11, *)) {
            [prefsDict writeToURL: url error: &writingError];
        } else {
            if (![prefsDict writeToURL: url atomically: true]) {
                writingError = [NSError errorWithDomain: kSuiteName code: 0 userInfo: @{
                    @"Error Reason": @"Unknown"
                }];
            }
        }

        if (writingError) {
            LOG(@"Writing whether notifications should be shown to disk failed with error: %@", writingError);
        }
    }

    + (BOOL)shouldShowNotifications {
        NSNumber * __nullable value = [self getBoolForKey:kPrefsKeyShouldShowNotifications];
        return value ? value.boolValue : true;
    }

    + (void)setShouldShowNotifications:(BOOL)shouldShowNotificationsFromNowOn {
        [self setBool:shouldShowNotificationsFromNowOn forKey:kPrefsKeyShouldShowNotifications];
    }

    + (BOOL)useTrollstoreMode {
        NSNumber * __nullable value = [self getBoolForKey:kPrefsKeyUseTrollstoreMode];
        return value ? value.boolValue : false;
    }

    + (void)setUseTrollstoreMode:(BOOL)useTrollstoreMode {
        [self setBool:useTrollstoreMode forKey:kPrefsKeyUseTrollstoreMode];
    }
@end

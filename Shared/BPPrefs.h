#import <Foundation/Foundation.h>

@interface BPPrefs: NSObject
    // Reads the prefs file and return whether to show notifications, or true by default
    + (BOOL) shouldShowNotifications;
    // Stores whether to show notifications in the prefs file
    + (void) setShouldShowNotifications:(BOOL)shouldShowNotificationsFromNowOn;

    // Whether to use 'trollstoreMode' (generate validation data by offsets on a copied and dlopen'ed
    // verion of identityservicesd instead of hooking into the system)
    + (BOOL)useTrollstoreMode;
    + (void)setUseTrollstoreMode:(BOOL)useTrollstoreMode;
@end

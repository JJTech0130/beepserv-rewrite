#import "BPOverviewViewController.h"
#import "../Shared/BPState.h"
#import "../Shared/BPPrefs.h"
#import "../Shared/Constants.h"
#import "../Shared/NSDistributedNotificationCenter.h"
#import "../Shared/bp_ids_generate_with_offsets.h"
#import "../Controller/BPSocketConnectionManager.h"
#import <UIKit/UIKit.h>

@interface BPOverviewViewController ()
    // Only shown when we are connected and have a registration code
    @property (retain) UIView* connectionDetailsContainer;
    @property (retain) UILabel* codeLabel;
    @property (retain) UILabel* aboveCodeLabel;
    @property (retain) UILabel* belowCodeLabel;

    // Only shown when we are not connected
    @property (retain) UILabel* noConnectionLabel;

    // Only shown before we receive a state update from the Controller
    @property (retain) UIActivityIndicatorView* activityIndicatorView;

    @property (retain) UIView* prefsContainer;
    @property (retain) UILabel* notificationsSwitchLabel;
    @property (retain) UISwitch* notificationsSwitch;

    @property (retain) UILabel* trollstoreModeLabel;
    @property (retain) UISwitch* trollstoreModeSwitch;

    // Used just to retain the BPSocketConnectionManager when we're using trollstoremode
    // we'll still be communicating to it over NSDistributedNotificationCenter, since that's
    // most compatible between different versions (daemon vs trollstore)
    @property (retain, nullable) id connectionManager;
@end

@implementation BPOverviewViewController
    @synthesize connectionDetailsContainer;
    @synthesize codeLabel;
    @synthesize aboveCodeLabel;
    @synthesize belowCodeLabel;
    @synthesize noConnectionLabel;
    @synthesize activityIndicatorView;
    @synthesize prefsContainer;
    @synthesize notificationsSwitchLabel;
    @synthesize notificationsSwitch;
    @synthesize trollstoreModeLabel;
    @synthesize trollstoreModeSwitch;

    - (void) viewDidLoad {
        [super viewDidLoad];

        if (@available(iOS 13, *)) {
            self.view.backgroundColor = [UIColor systemBackgroundColor];
        } else {
            self.view.backgroundColor = [UIColor whiteColor];
        }

        [self addNavigationBarButtonItems];
        [self addViews];
        [self addStateUpdateListener];
        [self requestStateUpdate];

        // Only start this up after we've started listening to updates from it
        if ([BPPrefs useTrollstoreMode]) {
            self.connectionManager = BPSocketConnectionManager.sharedInstance;
            [self.connectionManager startConnection];
        }
    }

    - (void) addNavigationBarButtonItems {
        UIBarButtonItem* newRegistrationCodeRequestButtonItem = [[UIBarButtonItem alloc]
            initWithTitle: @"Request new code"
            style: UIBarButtonItemStylePlain
            target: self
            action: @selector(handleNewRegistrationCodeRequestButtonPressed)
        ];
        self.navigationItem.rightBarButtonItem = newRegistrationCodeRequestButtonItem;
    }

    - (void) addViews {
        [self addConnectionDetailsContainer];
        [self addNoConnectionLabel];
        [self addActivityIndicatorView];
        [self addNotificationPrefsContainer];
    }

    - (void) addConnectionDetailsContainer {
        connectionDetailsContainer = [[UIView alloc] init];
        connectionDetailsContainer.translatesAutoresizingMaskIntoConstraints = false;

        [self.view addSubview: connectionDetailsContainer];

        if (@available(iOS 11, *)) {
            [connectionDetailsContainer.centerYAnchor constraintEqualToAnchor: self.view.safeAreaLayoutGuide.centerYAnchor].active = true;
            [connectionDetailsContainer.leftAnchor constraintEqualToAnchor: self.view.safeAreaLayoutGuide.leftAnchor constant: 32].active = true;
            [connectionDetailsContainer.rightAnchor constraintEqualToAnchor: self.view.safeAreaLayoutGuide.rightAnchor constant: -32].active = true;
        } else {
            [connectionDetailsContainer.centerYAnchor constraintEqualToAnchor: self.view.centerYAnchor].active = true;
            [connectionDetailsContainer.leftAnchor constraintEqualToAnchor: self.view.leftAnchor constant: 32].active = true;
            [connectionDetailsContainer.rightAnchor constraintEqualToAnchor: self.view.rightAnchor constant: -32].active = true;
        }

        aboveCodeLabel = [[UILabel alloc] init];
        aboveCodeLabel.translatesAutoresizingMaskIntoConstraints = false;
        aboveCodeLabel.textAlignment = NSTextAlignmentCenter;
        aboveCodeLabel.font = [UIFont systemFontOfSize: 17];
        aboveCodeLabel.text = @"Enter the registration code";

        [connectionDetailsContainer addSubview: aboveCodeLabel];

        [aboveCodeLabel.topAnchor constraintEqualToAnchor: connectionDetailsContainer.topAnchor].active = true;
        [aboveCodeLabel.leftAnchor constraintEqualToAnchor: connectionDetailsContainer.leftAnchor].active = true;
        [aboveCodeLabel.rightAnchor constraintEqualToAnchor: connectionDetailsContainer.rightAnchor].active = true;

        codeLabel = [[UILabel alloc] init];
        codeLabel.numberOfLines = 10;
        codeLabel.translatesAutoresizingMaskIntoConstraints = false;
        codeLabel.textAlignment = NSTextAlignmentCenter;
        codeLabel.font = [UIFont boldSystemFontOfSize:38];
        codeLabel.text = @"AAAA\nBBBB\nCCCC\nDDDD";

        [connectionDetailsContainer addSubview: codeLabel];

        [codeLabel.topAnchor constraintEqualToAnchor: aboveCodeLabel.bottomAnchor constant: 10].active = true;
        [codeLabel.leftAnchor constraintEqualToAnchor: connectionDetailsContainer.leftAnchor].active = true;
        [codeLabel.rightAnchor constraintEqualToAnchor: connectionDetailsContainer.rightAnchor].active = true;

        belowCodeLabel = [[UILabel alloc] init];
        belowCodeLabel.translatesAutoresizingMaskIntoConstraints = false;
        belowCodeLabel.textAlignment = NSTextAlignmentCenter;
        belowCodeLabel.font = [UIFont systemFontOfSize: 17];
        belowCodeLabel.text = @"to use this device";

        [connectionDetailsContainer addSubview: belowCodeLabel];

        [belowCodeLabel.topAnchor constraintEqualToAnchor: codeLabel.bottomAnchor constant: 10].active = true;
        [belowCodeLabel.bottomAnchor constraintEqualToAnchor: connectionDetailsContainer.bottomAnchor].active = true;
        [belowCodeLabel.leftAnchor constraintEqualToAnchor: connectionDetailsContainer.leftAnchor].active = true;
        [belowCodeLabel.rightAnchor constraintEqualToAnchor: connectionDetailsContainer.rightAnchor].active = true;

        connectionDetailsContainer.hidden = true;
    }

    - (void) addNoConnectionLabel {
        noConnectionLabel = [[UILabel alloc] init];
        noConnectionLabel.numberOfLines = 2;
        noConnectionLabel.translatesAutoresizingMaskIntoConstraints = false;
        noConnectionLabel.textAlignment = NSTextAlignmentCenter;
        noConnectionLabel.font = [UIFont boldSystemFontOfSize: 24];
        noConnectionLabel.textColor = [UIColor redColor];
        noConnectionLabel.text = @"Not connected\nto registration relay";

        [self.view addSubview: noConnectionLabel];

        if (@available(iOS 11, *)) {
            [noConnectionLabel.centerYAnchor constraintEqualToAnchor: self.view.safeAreaLayoutGuide.centerYAnchor].active = true;
        } else {
            [noConnectionLabel.centerYAnchor constraintEqualToAnchor: self.view.centerYAnchor].active = true;
        }

        [noConnectionLabel.leftAnchor constraintEqualToAnchor: self.view.leftAnchor constant: 32].active = true;
        [noConnectionLabel.rightAnchor constraintEqualToAnchor: self.view.rightAnchor constant: -32].active = true;

        noConnectionLabel.hidden = true;
    }

    - (void) addActivityIndicatorView {
        activityIndicatorView = [[UIActivityIndicatorView alloc] init];
        activityIndicatorView.translatesAutoresizingMaskIntoConstraints = false;
        activityIndicatorView.hidesWhenStopped = true;

        if (@available(iOS 13, *)) {
            activityIndicatorView.activityIndicatorViewStyle = UIActivityIndicatorViewStyleLarge;
        }

        [self.view addSubview: activityIndicatorView];

        [activityIndicatorView.centerXAnchor constraintEqualToAnchor: self.view.centerXAnchor].active = true;
        [activityIndicatorView.centerYAnchor constraintEqualToAnchor: self.view.centerYAnchor].active = true;

        [activityIndicatorView startAnimating];
    }

    - (void) addNotificationPrefsContainer {
        prefsContainer = [[UIView alloc] init];
        prefsContainer.translatesAutoresizingMaskIntoConstraints = false;

        [self.view addSubview: prefsContainer];

        if (@available(iOS 11, *)) {
            [prefsContainer.bottomAnchor constraintEqualToAnchor: self.view.safeAreaLayoutGuide.bottomAnchor constant: -32].active = true;
            [prefsContainer.centerXAnchor constraintEqualToAnchor: self.view.safeAreaLayoutGuide.centerXAnchor].active = true;
        } else {
            [prefsContainer.bottomAnchor constraintEqualToAnchor: self.view.bottomAnchor constant: -32].active = true;
            [prefsContainer.centerXAnchor constraintEqualToAnchor: self.view.centerXAnchor].active = true;
        }

        UILabel * __nonnull(^labelWithString)(NSString * __nonnull) = ^UILabel * __nonnull(NSString * __nonnull labelString){
            UILabel *label = UILabel.new;
            label.translatesAutoresizingMaskIntoConstraints = false;
            label.textAlignment = NSTextAlignmentCenter;
            label.font = [UIFont systemFontOfSize: 17];
            label.text = labelString;
            return label;
        };

        // MARK: Add trollstore stuff
        // label first
        trollstoreModeLabel = labelWithString(@"Trollstore Mode");

        [prefsContainer addSubview:trollstoreModeLabel];

        [trollstoreModeLabel.leftAnchor constraintEqualToAnchor:prefsContainer.leftAnchor].active = true;
        [trollstoreModeLabel.bottomAnchor constraintEqualToAnchor:prefsContainer.bottomAnchor].active = true;

        // then add switch
        trollstoreModeSwitch = UISwitch.new;
        trollstoreModeSwitch.translatesAutoresizingMaskIntoConstraints = false;
        [prefsContainer addSubview:trollstoreModeSwitch];

        [trollstoreModeSwitch.leftAnchor constraintEqualToAnchor:trollstoreModeLabel.rightAnchor constant:16].active = true;
        // [trollstoreModeSwitch.rightAnchor constraintEqualToAnchor:prefsContainer.rightAnchor].active = true;
        [trollstoreModeSwitch.bottomAnchor constraintEqualToAnchor:prefsContainer.bottomAnchor].active = true;

        trollstoreModeSwitch.on = [BPPrefs useTrollstoreMode];
        [trollstoreModeSwitch addTarget:self action:@selector(handleTrollstoreModeSwitchToggled) forControlEvents:UIControlEventValueChanged];

        // MARK: Notifications stuff
        // label first
        notificationsSwitchLabel = labelWithString(@"Local state notifications");

        [prefsContainer addSubview: notificationsSwitchLabel];

        [notificationsSwitchLabel.leftAnchor constraintEqualToAnchor: prefsContainer.leftAnchor].active = true;
        [notificationsSwitchLabel.bottomAnchor constraintEqualToAnchor: trollstoreModeLabel.topAnchor constant:-16].active = true;
        [notificationsSwitchLabel.topAnchor constraintEqualToAnchor:prefsContainer.topAnchor].active = true;

        // then add switch
        notificationsSwitch = [[UISwitch alloc] init];
        notificationsSwitch.translatesAutoresizingMaskIntoConstraints = false;
        [prefsContainer addSubview: notificationsSwitch];

        [notificationsSwitch.leftAnchor constraintEqualToAnchor: notificationsSwitchLabel.rightAnchor constant: 16].active = true;
        [notificationsSwitch.rightAnchor constraintEqualToAnchor: prefsContainer.rightAnchor].active = true;
        [notificationsSwitch.bottomAnchor constraintEqualToAnchor: trollstoreModeSwitch.topAnchor].active = true;

        notificationsSwitch.on = [BPPrefs shouldShowNotifications];

        [notificationsSwitch addTarget: self action: @selector(handleNotificationsSwitchToggled) forControlEvents: UIControlEventValueChanged];
    }

    - (void) handleNotificationsSwitchToggled {
        [BPPrefs setShouldShowNotifications: notificationsSwitch.on];
    }

    - (void) handleTrollstoreModeSwitchToggled {
        BOOL toggledOn = trollstoreModeSwitch.on;
        [BPPrefs setUseTrollstoreMode:toggledOn];

        // Kill the daemon since we don't need it anymore
        if (toggledOn) {
            [NSDistributedNotificationCenter.defaultCenter
                postNotificationName:kNotificationKillDaemon
                object:nil
                userInfo:nil
            ];
        }

        // Just exit to force it to reload and reconnect
        exit(0);
    }

    - (void) addStateUpdateListener {
        // Listen for state updates from the Controller
        // and update the UI accordingly
        [NSDistributedNotificationCenter.defaultCenter
            addObserverForName: kNotificationUpdateState
            object: nil
            queue: NSOperationQueue.mainQueue
            usingBlock: ^(NSNotification* notification)
        {
            BPState* currentState = [BPState createFromDictionary: notification.userInfo];
            [self updateWithState: currentState];
        }];
    }

    - (void) requestStateUpdate {
        // Request an initial state update from the Controller
        [[NSDistributedNotificationCenter defaultCenter]
            postNotificationName: kNotificationRequestStateUpdate
            object: nil
            userInfo: nil
        ];
    }

    - (void) updateWithState:(BPState*)state {
        [activityIndicatorView stopAnimating];

        if (state.isConnected) {
            // We have to escape the question marks because the compiler will
            // think it's a trigraph otherwise
            codeLabel.text = [(state.code ?: @"\?\?\?\?-\?\?\?\?-\?\?\?\?-\?\?\?\?") stringByReplacingOccurrencesOfString: @"-" withString: @"\n"];

            noConnectionLabel.hidden = true;
            connectionDetailsContainer.hidden = false;
        } else {
            noConnectionLabel.hidden = false;
            connectionDetailsContainer.hidden = true;
        }
    }

    - (void) handleNewRegistrationCodeRequestButtonPressed {
        // Request a new registration code from the Controller
        [[NSDistributedNotificationCenter defaultCenter]
            postNotificationName: kNotificationRequestNewRegistrationCode
            object: nil
            userInfo: nil
        ];
    }
@end

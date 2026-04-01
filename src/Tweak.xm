#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <substrate.h>

static BOOL     gIsResigningActive = NO;
static AVPlayer *gCurrentPlayer    = nil;

// ================ Hook C-level ================ //
static OSStatus (*orig_AudioSessionSetActive)(Boolean active);
static OSStatus replaced_AudioSessionSetActive(Boolean active) {
    if (!active) return noErr;
    return orig_AudioSessionSetActive(active);
}

// NSBundle hook removed – YouTube 1.1.0 already has UIBackgroundModes=audio in Info.plist
// Info.plist is patched at runtime via ctor if missing

// ================ iPad hooks ================
%hook YTPlayerScreenController
- (void)willLoseFocus {}
- (void)destroyLocalPlayerController {
    if ([UIApplication sharedApplication].applicationState == UIApplicationStateBackground) return;
    %orig;
}
%end

%hook YTWatchViewController_iPad
- (void)willResignTop {}
%end

// ================ UIApplication hook ================ //
%hook UIApplication
- (void)applicationWillResignActive:(id)delegate {
    gIsResigningActive = YES;
    NSError *error = nil;
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:&error];
    [[AVAudioSession sharedInstance] setActive:YES error:&error];
    %orig;
    gIsResigningActive = NO;
}
%end

// ================ AVPlayer hooks ================ //
%hook AVPlayer
- (void)play {
    gCurrentPlayer = self;
    %orig;
}
- (void)pause {
    if (gIsResigningActive ||
        [UIApplication sharedApplication].applicationState != UIApplicationStateActive) return;
    %orig;
}
- (void)setRate:(float)rate {
    if (rate == 0.0f &&
        (gIsResigningActive ||
         [UIApplication sharedApplication].applicationState != UIApplicationStateActive)) return;
    %orig;
}
%end

// ================ YTPlayer hooks ================ //
%hook YTPlayer
- (BOOL)backgroundPlaybackAllowed                  { return YES; }
- (void)setBackgroundPlaybackAllowed:(BOOL)arg1    { %orig(YES); }
- (void)appDidEnterBackground                      {}
- (void)appWillResignActive                        {}
- (void)pause {
    if (gIsResigningActive ||
        [UIApplication sharedApplication].applicationState != UIApplicationStateActive) return;
    %orig;
}
%end

// ================ YTPlayerController hooks ================ //
%hook YTPlayerController
- (BOOL)backgroundPlaybackAllowed                  { return YES; }
- (void)setBackgroundPlaybackAllowed:(BOOL)arg1    { %orig(YES); }
- (void)appDidEnterBackground                      {}
- (void)appWillResignActive                        {}
%end

// ================ AVAudioSession hooks ================ //
%hook GIPAudioController
- (void)setAudioSessionCategory:(id)category {
    NSError *error = nil;
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:&error];
    [[AVAudioSession sharedInstance] setActive:YES error:&error];
}
- (void)audioSessionSetActive {
    NSError *error = nil;
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:&error];
    [[AVAudioSession sharedInstance] setActive:YES error:&error];
}
- (void)audioSessionSetInactive {}
%end

%hook AVAudioSession
- (BOOL)setActive:(BOOL)active error:(NSError **)outError {
    if (!active) return YES;
    return %orig;
}
- (BOOL)setCategory:(NSString *)category error:(NSError **)outError {
    return %orig(AVAudioSessionCategoryPlayback, outError);
}
%end

// ================ Poll timer ================ //
static NSTimer *gPollTimer = nil;
static int      gPollCount = 0;

@interface YTBGPoller : NSObject
+ (void)tick:(NSTimer *)timer;
@end

@implementation YTBGPoller
+ (void)tick:(NSTimer *)timer {
    if ([UIApplication sharedApplication].applicationState != UIApplicationStateBackground ||
        gPollCount > 20) {
        [gPollTimer invalidate];
        gPollTimer = nil;
        gPollCount = 0;
        return;
    }
    gPollCount++;
    if (!gCurrentPlayer) return;

    NSError *err = nil;
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:&err];
    [[AVAudioSession sharedInstance] setActive:YES error:&err];

    if (gCurrentPlayer.rate == 0.0f) {
        [gCurrentPlayer play];
    }
}
@end

static void handleEnterBackground(CFNotificationCenterRef center, void *observer,
                                   CFStringRef name, const void *object,
                                   CFDictionaryRef userInfo) {
    [gPollTimer invalidate];
    gPollCount = 0;
    gPollTimer = [NSTimer scheduledTimerWithTimeInterval:0.5
                                                  target:[YTBGPoller class]
                                                selector:@selector(tick:)
                                                userInfo:nil
                                                 repeats:YES];
}

// ================ Constructor ================ //
%ctor {
    MSHookFunction(
        (void *)AudioSessionSetActive,
        (void *)replaced_AudioSessionSetActive,
        (void **)&orig_AudioSessionSetActive
    );

    // ================ Patch Info.plist ================ //
    NSBundle *mainBundle = [NSBundle mainBundle];
    NSArray  *bgModes    = [mainBundle objectForInfoDictionaryKey:@"UIBackgroundModes"];
    if (!bgModes || ![bgModes containsObject:@"audio"]) {
        NSString *plistPath = [[mainBundle bundlePath] stringByAppendingPathComponent:@"Info.plist"];
        NSMutableDictionary *plist = [NSMutableDictionary dictionaryWithContentsOfFile:plistPath];
        if (plist) {
            plist[@"UIBackgroundModes"] = @[@"audio"];
            [plist writeToFile:plistPath atomically:YES];
        }
    }

    NSError *error = nil;
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:&error];
    [[AVAudioSession sharedInstance] setActive:YES error:&error];

    CFNotificationCenterAddObserver(
        CFNotificationCenterGetLocalCenter(), NULL,
        handleEnterBackground,
        (CFStringRef)UIApplicationDidEnterBackgroundNotification,
        NULL, CFNotificationSuspensionBehaviorDeliverImmediately
    );

    // Welcome alert – shown once per install (auto-reset khi cài lại IPA)
    NSString *flagFile = [[[NSBundle mainBundle] bundlePath]
                          stringByAppendingPathComponent:@".ytbg_installed"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:flagFile]) {
        [[NSFileManager defaultManager] createFileAtPath:flagFile contents:nil attributes:nil];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            UIAlertView *alert = [[UIAlertView alloc]
                initWithTitle:@"YTBackgroundTweak"
                      message:@"Background Playback activated.\n\n© 2026 Tuanem. All rights reserved."
                     delegate:nil
            cancelButtonTitle:@"OK"
            otherButtonTitles:nil];
            [alert show];
#pragma clang diagnostic pop
        });
    }
}

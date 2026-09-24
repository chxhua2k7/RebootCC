//
//  RBCActions.m
//  三個動作的實作。模組跑在 SpringBoard(mobile):
//  - respring:spawn sbreload(uikittools),失敗才退回 FrontBoardServices 的 SBSRelaunchAction
//  - userspace reboot / 安全模式:spawn setuid root 的 RebootCCHelper(見 helper/main.c)
//

#import "RBCActions.h"
#import <dlfcn.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <spawn.h>
#import <sys/wait.h>

#ifndef THEOS_PACKAGE_INSTALL_PREFIX
#define THEOS_PACKAGE_INSTALL_PREFIX ""
#endif

#ifdef DEBUG
#define RBCLog(fmt, ...) NSLog(@"[RebootCC] " fmt, ##__VA_ARGS__)
#else
#define RBCLog(fmt, ...) do {} while (0)
#endif

extern char **environ;

static CFStringRef const kRBCPreferencesDomain = CFSTR("com.c3x14n.rebootcc");
static const char *const kRBCSbreloadPath = THEOS_PACKAGE_INSTALL_PREFIX "/usr/bin/sbreload";
static const char *const kRBCHelperPath = THEOS_PACKAGE_INSTALL_PREFIX "/usr/libexec/RebootCCHelper";

#pragma mark - 文字和圖示

NSString *RBCLocalized(NSString *key) {
    static NSBundle *bundle;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        bundle = [NSBundle bundleForClass:NSClassFromString(@"RBCModule")];
    });
    return [bundle localizedStringForKey:key value:key table:nil] ?: key;
}

NSString *RBCActionTitle(RBCAction action) {
    switch (action) {
        case RBCActionRespring: return RBCLocalized(@"Respring");
        case RBCActionUserspaceReboot: return RBCLocalized(@"Userspace Reboot");
        case RBCActionSafeMode: return RBCLocalized(@"Safe Mode");
        case RBCActionNone: break;
    }
    return @"";
}

UIImage *RBCActionGlyph(RBCAction action) {
    NSString *symbol = nil;
    switch (action) {
        case RBCActionRespring: symbol = @"arrow.clockwise"; break;
        case RBCActionUserspaceReboot: symbol = @"arrow.triangle.2.circlepath"; break;
        case RBCActionSafeMode: symbol = @"checkmark.shield"; break;
        case RBCActionNone: return nil;
    }
    return [UIImage systemImageNamed:symbol];
}

#pragma mark - 設定

BOOL RBCActionNeedsConfirm(RBCAction action) {
    if (action != RBCActionUserspaceReboot && action != RBCActionSafeMode) return NO;
    // 每次都重新讀,設定頁改了不必 respring
    CFPreferencesAppSynchronize(kRBCPreferencesDomain);
    Boolean valid = false;
    Boolean confirm = CFPreferencesGetAppBooleanValue(CFSTR("confirm"), kRBCPreferencesDomain, &valid);
    return valid ? confirm : YES;
}

#pragma mark - 執行

// 子程序另開 session,SpringBoard 被重啟時不會連帶收到訊號;在背景回收避免殭屍程序。
static BOOL RBCSpawn(const char *path, const char *argument) {
    posix_spawnattr_t attr;
    posix_spawnattr_init(&attr);
    posix_spawnattr_setflags(&attr, POSIX_SPAWN_SETSID);
    char *argv[] = { (char *)path, (char *)argument, NULL };
    pid_t pid = 0;
    int result = posix_spawn(&pid, path, NULL, &attr, argv, environ);
    posix_spawnattr_destroy(&attr);
    if (result != 0) {
        RBCLog(@"posix_spawn %s failed: %d", path, result);
        return NO;
    }
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        int status = 0;
        waitpid(pid, &status, 0);
        RBCLog(@"%s %s exited with status %d", path, argument ?: "", status);
    });
    return YES;
}

// 和設定頁「套用」相同的 respring(BootLogStop 的 blsRespring)
static void RBCRelaunchSpringBoard(void) {
    dlopen("/System/Library/PrivateFrameworks/FrontBoardServices.framework/FrontBoardServices", RTLD_NOW);
    dlopen("/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices", RTLD_NOW);
    Class actionClass = objc_getClass("SBSRelaunchAction");
    Class serviceClass = objc_getClass("FBSSystemService");
    if (!actionClass || !serviceClass) return;
    // SBSRelaunchActionOptionsRestartRenderServer = 1 << 0
    id action = ((id (*)(id, SEL, id, NSUInteger, id))objc_msgSend)(actionClass, @selector(actionWithReason:options:targetURL:), @"RebootCC", 1, nil);
    id service = ((id (*)(id, SEL))objc_msgSend)(serviceClass, @selector(sharedService));
    ((void (*)(id, SEL, id, id))objc_msgSend)(service, @selector(sendActions:withResult:), [NSSet setWithObject:action], nil);
}

void RBCPerform(RBCAction action) {
    switch (action) {
        case RBCActionRespring:
            if (!RBCSpawn(kRBCSbreloadPath, NULL)) RBCRelaunchSpringBoard();
            break;
        case RBCActionUserspaceReboot:
            RBCSpawn(kRBCHelperPath, "userspace");
            break;
        case RBCActionSafeMode:
            RBCSpawn(kRBCHelperPath, "safemode");
            break;
        case RBCActionNone:
            break;
    }
}

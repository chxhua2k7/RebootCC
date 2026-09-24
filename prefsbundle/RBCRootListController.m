//
//  RBCRootListController.m
//  設定頁的 controller。libprefs 的 PLLocalizedListController 負責從 PreferenceLoader
//  entry 旁邊的 plist(prefs/RebootCC.plist)載入項目並翻譯;這個子類加上:
//  - 列的 SF Symbol 圖示(和 NowLyrics / IslandSwipe / BootLogStop 同一套)
//  - 右上角「套用」按鈕:確認後透過 FrontBoardServices 的 SBSRelaunchAction 重啟 SpringBoard
//  模組每次點選都會重新讀設定,改設定其實不必 respring;按鈕是為了和其他 tweak 的設定頁一致。
//

#import <UIKit/UIKit.h>
#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <libprefs/prefs.h>
#import <dlfcn.h>
#import <objc/message.h>
#import <objc/runtime.h>

#ifndef RBC_VERSION
#error RBC_VERSION comes from PACKAGE_VERSION in the Makefile
#endif

@interface RBCRootListController : PLLocalizedListController
@end

#pragma mark - Icons(列上寫 iconSymbol / iconColor,執行期畫成 SF Symbol 圖示)

static const CGFloat kRBCIconSize = 29;
static const CGFloat kRBCIconCornerRadius = 6.5;
static const CGFloat kRBCIconGlyphPointSize = 15;

static UIColor *RBCColorFromHex(id value) {
    if (![value isKindOfClass:[NSString class]]) return nil;
    NSString *digits = [value hasPrefix:@"#"] ? [value substringFromIndex:1] : value;
    unsigned rgb = 0;
    if (digits.length != 6 || ![[NSScanner scannerWithString:digits] scanHexInt:&rgb]) return nil;
    return [UIColor colorWithRed:((rgb >> 16) & 0xFF) / 255.0 green:((rgb >> 8) & 0xFF) / 255.0 blue:(rgb & 0xFF) / 255.0 alpha:1];
}

static UIImage *RBCTileIcon(NSString *symbolName, UIColor *color) {
    UIImageSymbolConfiguration *configuration = [UIImageSymbolConfiguration configurationWithPointSize:kRBCIconGlyphPointSize weight:UIImageSymbolWeightMedium];
    UIImage *glyph = [[UIImage systemImageNamed:symbolName withConfiguration:configuration]
                      imageWithTintColor:UIColor.whiteColor renderingMode:UIImageRenderingModeAlwaysOriginal];
    CGRect tile = CGRectMake(0, 0, kRBCIconSize, kRBCIconSize);
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:tile.size];
    return [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
        [color setFill];
        [[UIBezierPath bezierPathWithRoundedRect:tile cornerRadius:kRBCIconCornerRadius] fill];
        if (!glyph) return;
        CGSize size = glyph.size;
        [glyph drawInRect:CGRectMake((kRBCIconSize - size.width) / 2, (kRBCIconSize - size.height) / 2, size.width, size.height)];
    }];
}

static void RBCApplyIcon(PSSpecifier *specifier) {
    if ([specifier propertyForKey:PSIconImageKey]) return;
    NSString *symbol = [specifier propertyForKey:@"iconSymbol"];
    UIColor *color = RBCColorFromHex([specifier propertyForKey:@"iconColor"]);
    if (![symbol isKindOfClass:[NSString class]] || !color) return;
    [specifier setProperty:RBCTileIcon(symbol, color) forKey:PSIconImageKey];
}

// 字串放在 PreferenceLoader 的 prefs 資料夾(和 plist 同一份 Localizable.strings)。
static NSString *RBCLocalized(NSString *key) {
    static NSBundle *bundle;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        for (NSString *root in @[@"/var/jb", @""]) {
            NSBundle *candidate = [NSBundle bundleWithPath:[root stringByAppendingString:@"/Library/PreferenceLoader/Preferences/RebootCC"]];
            if (candidate) { bundle = candidate; break; }
        }
    });
    return [bundle localizedStringForKey:key value:key table:nil] ?: key;
}

@implementation RBCRootListController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:RBCLocalized(@"Apply")
                                                                              style:UIBarButtonItemStyleDone
                                                                             target:self
                                                                             action:@selector(rbcApplyTapped)];
}

- (NSMutableArray *)specifiers {
    NSMutableArray *specifiers = [super specifiers];
    for (PSSpecifier *specifier in specifiers) RBCApplyIcon(specifier);
    return specifiers;
}

#pragma mark 「關於」

// 版本列(plist 的 get = rbcVersion:)。
- (NSString *)rbcVersion:(PSSpecifier *)specifier {
    return @RBC_VERSION;
}

#pragma mark 套用

- (void)rbcApplyTapped {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:RBCLocalized(@"Apply")
                                                                   message:RBCLocalized(@"Restart SpringBoard to apply?")
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:RBCLocalized(@"Cancel") style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:RBCLocalized(@"Respring") style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        [self rbcRespring];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)rbcRespring {
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

@end

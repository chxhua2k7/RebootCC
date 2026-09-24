//
//  RBCActions.h
//  模組的三個動作,和它們在選單上的文字、圖示。
//

#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, RBCAction) {
    RBCActionNone = 0,
    RBCActionRespring,
    RBCActionUserspaceReboot,
    RBCActionSafeMode,
};

// 模組 bundle 裡的 Localizable.strings
NSString *RBCLocalized(NSString *key);

NSString *RBCActionTitle(RBCAction action);
UIImage *RBCActionGlyph(RBCAction action);

// Userspace Reboot 和安全模式要不要點兩次(設定頁的 confirm,沒設定時是 YES)
BOOL RBCActionNeedsConfirm(RBCAction action);

void RBCPerform(RBCAction action);

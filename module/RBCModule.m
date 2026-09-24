//
//  RBCModule.m
//  控制中心模組(Info.plist 的 NSPrincipalClass)。CCSupport 在 SpringBoard 裡建立它。
//  - 點一下:respring
//  - 長按:展開選單,有 respring、userspace reboot、安全模式
//  - 後兩項預設要點兩次:第一次點時選單不收起,副標題改成「再點一次以確認」,4 秒內再點同一項才執行
//

#import "RBCPrivate.h"
#import "RBCActions.h"

static const NSTimeInterval kRBCConfirmWindow = 4;

@interface RBCModuleViewController : CCUIMenuModuleViewController
@end

@implementation RBCModuleViewController {
    RBCAction _pendingAction;       // 等待第二次點選的動作
    NSUInteger _pendingGeneration;  // 每次改變都加一,讓過期的倒數計時失效
}

- (void)viewDidLoad {
    [super viewDidLoad];
    UIImageSymbolConfiguration *configuration = [UIImageSymbolConfiguration configurationWithPointSize:24
                                                                                                weight:UIImageSymbolWeightRegular
                                                                                                 scale:UIImageSymbolScaleLarge];
    self.glyphImage = [UIImage systemImageNamed:@"arrow.clockwise" withConfiguration:configuration];
    self.title = @"RebootCC";
    [self rbcReloadMenu];
}

// 點一下
- (void)buttonTapped:(id)button forEvent:(UIEvent *)event {
    [super buttonTapped:button forEvent:event];
    RBCPerform(RBCActionRespring);
}

// 長按
- (BOOL)shouldBeginTransitionToExpandedContentModule {
    return YES;
}

// 展開或收起時都清掉待確認的狀態。實機上只在 viewDidLoad 加一次選單的話,收起後再展開
// 選單是空的,所以每次展開都重新加(CAPerfHUD 也是在這裡設定選單項目)。
- (void)willTransitionToExpandedContentMode:(BOOL)willTransition {
    [super willTransitionToExpandedContentMode:willTransition];
    _pendingAction = RBCActionNone;
    _pendingGeneration++;
    if (willTransition) [self rbcReloadMenu];
}

- (BOOL)_canShowWhileLocked {
    return YES;
}

#pragma mark 選單

- (void)rbcReloadMenu {
    [self removeAllActions];
    for (RBCAction action = RBCActionRespring; action <= RBCActionSafeMode; action++) {
        NSString *subtitle = (action == _pendingAction) ? RBCLocalized(@"Tap again to confirm") : nil;
        __weak typeof(self) weakSelf = self;
        [self addActionWithTitle:RBCActionTitle(action) subtitle:subtitle glyph:RBCActionGlyph(action) handler:^BOOL{
            return [weakSelf rbcHandleAction:action];
        }];
    }
    [self.view setNeedsLayout];
}

- (void)rbcSetPendingAction:(RBCAction)action {
    _pendingGeneration++;
    if (_pendingAction == action) return;
    _pendingAction = action;
    [self rbcReloadMenu];
}

// 回傳 YES 收起選單
- (BOOL)rbcHandleAction:(RBCAction)action {
    if (RBCActionNeedsConfirm(action) && _pendingAction != action) {
        // 在 handler 裡重建選單不安全(super 還在處理這次點選),下一輪再做
        dispatch_async(dispatch_get_main_queue(), ^{
            [self rbcSetPendingAction:action];
            NSUInteger generation = self->_pendingGeneration;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kRBCConfirmWindow * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                if (self->_pendingGeneration == generation) [self rbcSetPendingAction:RBCActionNone];
            });
        });
        return NO;
    }
    _pendingAction = RBCActionNone;
    _pendingGeneration++;
    RBCPerform(action);
    return YES;
}

@end

@interface RBCModule : NSObject <CCUIContentModule>
@end

@implementation RBCModule {
    RBCModuleViewController *_contentViewController;
}

- (instancetype)init {
    if ((self = [super init])) {
        _contentViewController = [[RBCModuleViewController alloc] initWithNibName:nil bundle:nil];
    }
    return self;
}

- (UIViewController<CCUIContentModuleContentViewController> *)contentViewController {
    return _contentViewController;
}

- (UIViewController *)backgroundViewController {
    return nil;
}

@end

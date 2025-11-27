#import "CDVStatusBar.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import <Cordova/CDVViewController.h>
#import <UIKit/UIKit.h>

static const void *kHideStatusBar = &kHideStatusBar;
static const void *kStatusBarStyle = &kStatusBarStyle;

#pragma mark - CDVViewController category for status bar props

@interface CDVViewController (StatusBar)
@property (nonatomic, retain) id sb_hideStatusBar;
@property (nonatomic, retain) id sb_statusBarStyle;
@end

@implementation CDVViewController (StatusBar)
@dynamic sb_hideStatusBar;
@dynamic sb_statusBarStyle;

- (id)sb_hideStatusBar { return objc_getAssociatedObject(self, kHideStatusBar); }
- (void)setSb_hideStatusBar:(id)v { objc_setAssociatedObject(self, kHideStatusBar, v, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }

- (id)sb_statusBarStyle { return objc_getAssociatedObject(self, kStatusBarStyle); }
- (void)setSb_statusBarStyle:(id)v { objc_setAssociatedObject(self, kStatusBarStyle, v, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }

- (BOOL)prefersStatusBarHidden { return [self.sb_hideStatusBar boolValue]; }
- (UIStatusBarStyle)preferredStatusBarStyle { return (UIStatusBarStyle)[self.sb_statusBarStyle intValue]; }

@end

#pragma mark - CDVStatusBar

@interface CDVStatusBar () <UIScrollViewDelegate>

@property (nonatomic, assign, readwrite) BOOL statusBarOverlaysWebView;
@property (nonatomic, strong) UIView *statusBarBackgroundView;
// NEW: translucent overlay and base color
@property (nonatomic, strong) UIView *statusBarOverlayView;
@property (nonatomic, strong) UIColor *statusBarBaseColor;

@property (nonatomic, assign) BOOL uiviewControllerBasedStatusBarAppearance;
@property (nonatomic, strong) UIColor *statusBarBackgroundColor;
@property (nonatomic, copy) NSString *eventsCallbackId;
@property (nonatomic, assign) BOOL statusBarVisible;
@property (nonatomic, strong) NSString* safeAreaCallbackId;
@property (nonatomic, strong) UIScrollView *fakeScrollView;
@property (nonatomic, assign, readwrite) BOOL keepInsets;
@property (nonatomic, assign) CGFloat storedSafeAreaTop;

- (void)updateIsVisible:(BOOL)visible;
@end

@implementation CDVStatusBar

#pragma mark - Helpers

+ (CGRect)statusBarFrameForViewController:(UIViewController*)vc {
    CGRect statusBarFrame = CGRectZero;
    if (@available(iOS 13.0, *)) {
        UIWindow *window = vc.view.window;
        if (!window) {
            // fallback to first connected window
            window = [UIApplication sharedApplication].windows.firstObject;
        }
        if (window && window.windowScene && window.windowScene.statusBarManager) {
            statusBarFrame = window.windowScene.statusBarManager.statusBarFrame;
        } else {
            CGFloat topInset = vc.view.safeAreaInsets.top;
            statusBarFrame = CGRectMake(0, 0, CGRectGetWidth(vc.view.bounds), topInset);
        }
    } else {
        statusBarFrame = [UIApplication sharedApplication].statusBarFrame;
    }
    return statusBarFrame;
}

+ (UIStatusBarManager *)currentStatusBarManagerForViewController:(UIViewController *)vc {
    if (@available(iOS 13.0, *)) {
        UIWindow *window = vc.view.window;
        if (!window) {
            // fallback to first connected window
            window = [UIApplication sharedApplication].windows.firstObject;
        }
        if (window && window.windowScene) {
            return window.windowScene.statusBarManager;
        } else {
            return nil; // manager not available yet
        }
    } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        // Before iOS 13 there is no UIStatusBarManager, so return nil
        return nil;
#pragma clang diagnostic pop
    }
}



- (UIColor*)colorFromHex:(NSString*)hexString {
    if (!hexString) return nil;
    NSString *hex = [hexString stringByReplacingOccurrencesOfString:@"#" withString:@""];
    unsigned int rgbValue = 0;
    CGFloat alpha = 1.0f;

    if (hex.length == 8) {
        NSString *rgbHex = [hex substringToIndex:6];
        NSString *aHex = [hex substringFromIndex:6];
        NSScanner *sc = [NSScanner scannerWithString:rgbHex]; [sc scanHexInt:&rgbValue];
        unsigned int aValue = 255;
        [[NSScanner scannerWithString:aHex] scanHexInt:&aValue];
        alpha = aValue / 255.0f;
    } else if (hex.length == 6) {
        NSScanner *sc = [NSScanner scannerWithString:hex];
        [sc scanHexInt:&rgbValue];
    } else {
        return nil;
    }

    return [UIColor colorWithRed:((rgbValue & 0xFF0000) >> 16)/255.0f
                           green:((rgbValue & 0xFF00) >> 8)/255.0f
                            blue:(rgbValue & 0xFF)/255.0f
                           alpha:alpha];
}

#pragma mark - Lifecycle

- (id)settingForKey:(NSString*)key {
    return [self.commandDelegate.settings objectForKey:[key lowercaseString]];
}

- (void)pluginInitialize {
    NSNumber* uiviewControllerBased = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"UIViewControllerBasedStatusBarAppearance"];
    self.uiviewControllerBasedStatusBarAppearance = (uiviewControllerBased == nil || [uiviewControllerBased boolValue]);

    // try KVO on statusBarHidden (some iOS versions may throw, so try/catch)
    @try {
        [[UIApplication sharedApplication] addObserver:self forKeyPath:@"statusBarHidden" options:NSKeyValueObservingOptionNew context:NULL];
    } @catch (NSException *e) { /* ignore */ }

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(statusBarDidChangeFrame:) name:UIApplicationDidChangeStatusBarFrameNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(cordovaViewWillAppear:) name:@"CDVViewWillAppearNotification" object:nil];
    CGRect sbFrame = [CDVStatusBar statusBarFrameForViewController:self.viewController];
    CGFloat statusBarHeight = sbFrame.size.height;
    if (statusBarHeight > 0) {
        self.storedSafeAreaTop = statusBarHeight;
    }
   
    // default: do NOT overlay; push content below status bar
    self.statusBarOverlaysWebView = NO;
    UIStatusBarManager *statusBarManager = [CDVStatusBar currentStatusBarManagerForViewController:self.viewController];

    self.statusBarVisible = !statusBarManager.isStatusBarHidden;

    [self initializeStatusBarBackgroundView];

    // attach background view if not overlaying
    if (!self.statusBarOverlaysWebView) {
        if (self.webView && self.webView.superview) {
            [self.webView.superview addSubview:self.statusBarBackgroundView];
        } else {
            [self.viewController.view addSubview:self.statusBarBackgroundView];
        }
    }

    self.viewController.view.autoresizesSubviews = YES;

    // respect config overrides if present
    NSString* bg = [self settingForKey:@"StatusBarBackgroundColor"];
    if (bg && [bg isKindOfClass:[NSString class]]) {
        if ([bg hasPrefix:@"#"]) { [self _backgroundColorByHexString:bg]; }
        else { [self backgroundColorByName:[CDVInvokedUrlCommand commandFromJson:@[bg]]]; }
    }

    NSString* style = [self settingForKey:@"StatusBarStyle"];
    if (style && [style isKindOfClass:[NSString class]]) {
        [self setStatusBarStyle:style];
    }

    // default scroll-to-top behavior
    id scrollToTop = [self settingForKey:@"StatusBarDefaultScrollToTop"];
    UIScrollView *sv = [self webViewScrollView];
    if (sv) {
        sv.scrollsToTop = (scrollToTop ? [(NSNumber*)scrollToTop boolValue] : NO);
    }

    self.fakeScrollView = [[UIScrollView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.fakeScrollView.delegate = self;
    self.fakeScrollView.scrollsToTop = YES;
    self.fakeScrollView.contentSize = CGSizeMake([UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height * 2.0f);
    self.fakeScrollView.contentOffset = CGPointMake(0.0f, [UIScreen mainScreen].bounds.size.height);
    self.fakeScrollView.userInteractionEnabled = YES;
    self.fakeScrollView.backgroundColor = [UIColor clearColor];
    [self.viewController.view addSubview:self.fakeScrollView];
    [self.viewController.view sendSubviewToBack:self.fakeScrollView];
}

- (void)dealloc {
    @try { [[UIApplication sharedApplication] removeObserver:self forKeyPath:@"statusBarHidden"]; } @catch (NSException *e) {}
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidChangeStatusBarFrameNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"CDVViewWillAppearNotification" object:nil];

    if (@available(iOS 11.0, *)) {
        @try {
            [self.viewController.view removeObserver:self forKeyPath:@"safeAreaInsets"];
        } @catch (NSException *e) {}
    }
}

#pragma mark - Observers / Notifications

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey,id> *)change
                       context:(void *)context
{
    if ([keyPath isEqualToString:@"statusBarHidden"]) {
        NSNumber* newVal = change[NSKeyValueChangeNewKey];
        [self updateIsVisible:![newVal boolValue]];
    }
    else if ([keyPath isEqualToString:@"safeAreaInsets"]) {
        UIEdgeInsets insets = [change[NSKeyValueChangeNewKey] UIEdgeInsetsValue];
        
        NSDictionary* result = @{
            @"top": @(insets.top),
            @"left": @(insets.left),
            @"bottom": @(insets.bottom),
            @"right": @(insets.right)
        };

        CDVPluginResult* pluginResult =
        [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                       messageAsDictionary:result];
        
        [pluginResult setKeepCallbackAsBool:YES];

        [self.commandDelegate sendPluginResult:pluginResult
                                    callbackId:self.safeAreaCallbackId];
    }
    else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)cordovaViewWillAppear:(NSNotification*)notification {
    __weak CDVStatusBar* weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [weakSelf resizeWebView];
    });
}

- (void)statusBarDidChangeFrame:(NSNotification*)notification {
    __weak CDVStatusBar* weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [weakSelf resizeStatusBarBackgroundView];
        [weakSelf resizeWebView];
    });
}

#pragma mark - Public API (TypeScript-facing)

- (void)isReady:(CDVInvokedUrlCommand*)command {
    // register callback (optional)
    if (command.callbackId) {
        self.eventsCallbackId = command.callbackId;
    }
    UIStatusBarManager *statusBarManager = [CDVStatusBar currentStatusBarManagerForViewController:self.viewController];
    // reply current visibility and keep callback so JS can listen later
    CDVPluginResult* res = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:!statusBarManager.statusBarHidden];
    [res setKeepCallbackAsBool:YES];
    [self.commandDelegate sendPluginResult:res callbackId:command.callbackId];
}

- (void)overlaysWebView:(CDVInvokedUrlCommand*)command {
    id arg = [command argumentAtIndex:0];
    BOOL overlays = NO;
    if ([arg isKindOfClass:[NSNumber class]]) overlays = [(NSNumber*)arg boolValue];
    else if ([arg isKindOfClass:[NSString class]]) overlays = [(NSString*)arg boolValue];

    if (overlays == self.statusBarOverlaysWebView) {
        return;
    }
    self.statusBarOverlaysWebView = overlays;
    [self resizeWebView];

    if (self.statusBarOverlaysWebView) {
        [self.statusBarBackgroundView removeFromSuperview];
    } else {
        [self initializeStatusBarBackgroundView];
        if (self.webView && self.webView.superview) [self.webView.superview addSubview:self.statusBarBackgroundView];
        else [self.viewController.view addSubview:self.statusBarBackgroundView];
    }
}

- (void)backgroundColorByName:(CDVInvokedUrlCommand*)command {
    id value = [command argumentAtIndex:0];
    if (![value isKindOfClass:[NSString class]]) value = @"black";
    SEL sel = NSSelectorFromString([value stringByAppendingString:@"Color"]);
    if ([UIColor respondsToSelector:sel]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        self.statusBarBackgroundView.backgroundColor = [UIColor performSelector:sel];
#pragma clang diagnostic pop
    }
}

- (void)backgroundColorByHexString:(CDVInvokedUrlCommand*)command {
    NSString* hex = [command argumentAtIndex:0];
    if (![hex isKindOfClass:[NSString class]]) return;
    if (![hex hasPrefix:@"#"] || hex.length < 7) return;
    [self _backgroundColorByHexString:hex];
}

- (void)navigationBackgroundColorByHexString:(CDVInvokedUrlCommand*)command {
    NSString* hex = [command argumentAtIndex:0];
    if (![hex isKindOfClass:[NSString class]]) return;
    UIColor *c = [self colorFromHex:hex];
    if (!c) return;

    // If the app has a navigation controller, tint it; otherwise use appearance proxy
    UINavigationController *nav = self.viewController.navigationController;
    if (nav && nav.navigationBar) {
        if (@available(iOS 13.0, *)) {
            nav.navigationBar.barTintColor = c;
            nav.navigationBar.backgroundColor = c;
            nav.navigationBar.translucent = NO;
        } else {
            nav.navigationBar.barTintColor = c;
            nav.navigationBar.translucent = NO;
        }
    } else {
        if (@available(iOS 13.0, *)) {
            UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
            [appearance configureWithOpaqueBackground];
            appearance.backgroundColor = c;
            [UINavigationBar appearance].standardAppearance = appearance;
            [UINavigationBar appearance].scrollEdgeAppearance = appearance;
        } else {
            [UINavigationBar appearance].barTintColor = c;
            [UINavigationBar appearance].translucent = NO;
        }
    }
}

- (void)getSafeAreaInsets:(CDVInvokedUrlCommand*)command {
    UIEdgeInsets insets = self.viewController.view.safeAreaInsets;

    NSDictionary *result = @{
        @"top": @(insets.top),
        @"bottom": @(insets.bottom),
        @"left": @(insets.left),
        @"right": @(insets.right)
    };

    CDVPluginResult *pluginResult =
        [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                       messageAsDictionary:result];

    [self.commandDelegate sendPluginResult:pluginResult
                                callbackId:command.callbackId];
}

- (void)subscribeSafeAreaInsets:(CDVInvokedUrlCommand*)command {
    if (self.safeAreaCallbackId) {
        // already subscribed — optionally replace callback id
        self.safeAreaCallbackId = command.callbackId;
        return;
    }
    // Keep callback alive
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                   messageAsDictionary:@{}];
    [pluginResult setKeepCallbackAsBool:YES];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];

    __weak CDVStatusBar* weakSelf = self;
    self.safeAreaCallbackId = command.callbackId;
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController* vc = weakSelf.viewController;
        [vc.view addObserver:weakSelf
                  forKeyPath:@"safeAreaInsets"
                     options:NSKeyValueObservingOptionNew
                     context:(__bridge void * _Nullable)(command.callbackId)];
    });
}

- (void)hide:(CDVInvokedUrlCommand*)command {
    self.statusBarVisible = NO;
    BOOL keepInsets = NO;
    id arg = [command argumentAtIndex:0];
    if ([arg isKindOfClass:[NSNumber class]]) keepInsets = [(NSNumber*)arg boolValue];
    else if ([arg isKindOfClass:[NSString class]]) keepInsets = [(NSString*)arg boolValue];
    self.keepInsets = keepInsets;
    UIStatusBarManager *statusBarManager = [CDVStatusBar currentStatusBarManagerForViewController:self.viewController];
    if (!statusBarManager.isStatusBarHidden) {
        [self hideStatusBar];
        [self resizeWebView];
        [self.statusBarBackgroundView removeFromSuperview];
        self.statusBarBackgroundView.hidden = YES;
    }
    if (!keepInsets) {
        self.safeAreaCallbackId = nil;
    }
}

- (void)show:(CDVInvokedUrlCommand*)command {
    self.statusBarVisible = YES;
    BOOL keepInsets = NO;
    id arg = [command argumentAtIndex:0];
    if ([arg isKindOfClass:[NSNumber class]]) keepInsets = [(NSNumber*)arg boolValue];
    else if ([arg isKindOfClass:[NSString class]]) keepInsets = [(NSString*)arg boolValue];
    self.keepInsets = keepInsets;
    UIStatusBarManager *statusBarManager = [CDVStatusBar currentStatusBarManagerForViewController:self.viewController];
    if (statusBarManager.isStatusBarHidden) {
        [self showStatusBar];
        [self resizeWebView];

        if (!self.statusBarOverlaysWebView) {
            [self initializeStatusBarBackgroundView];
            if (self.webView && self.webView.superview) [self.webView.superview addSubview:self.statusBarBackgroundView];
            else [self.viewController.view addSubview:self.statusBarBackgroundView];
        }
        self.statusBarBackgroundView.hidden = NO;
    }

    if (!keepInsets) {
        // optionally reset safe area callback / insets logic
        self.safeAreaCallbackId = nil;
    }
}

- (void)styleDefault:(CDVInvokedUrlCommand*)command {
    if (@available(iOS 13.0, *)) [self setStyleForStatusBar:UIStatusBarStyleDarkContent];
    else [self setStyleForStatusBar:UIStatusBarStyleDefault];
}

- (void)styleLightContent:(CDVInvokedUrlCommand*)command {
    [self setStyleForStatusBar:UIStatusBarStyleLightContent];
}

#pragma mark - Internals (kept but compact)

- (void)fireTappedEvent {
    if (self.eventsCallbackId == nil) return;
    NSDictionary* payload = @{@"type": @"tap"};
    CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:payload];
    [result setKeepCallbackAsBool:YES];
    [self.commandDelegate sendPluginResult:result callbackId:self.eventsCallbackId];
}

- (void)updateIsVisible:(BOOL)visible {
    if (self.eventsCallbackId == nil) return;
    CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:visible];
    [result setKeepCallbackAsBool:YES];
    [self.commandDelegate sendPluginResult:result callbackId:self.eventsCallbackId];
}
- (void)initializeStatusBarBackgroundView {
    CGRect statusBarFrame = [CDVStatusBar statusBarFrameForViewController:self.viewController];
    if (!self.statusBarBackgroundView) {
        // Container view (base color)
        self.statusBarBackgroundView = [[UIView alloc] initWithFrame:statusBarFrame];
        self.statusBarBackgroundView.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin);
        self.statusBarBackgroundView.autoresizesSubviews = YES;
        self.statusBarBackgroundView.opaque = NO; // allow transparency
    } else {
        self.statusBarBackgroundView.frame = statusBarFrame;
    }

    // Ensure base color is applied (if any). If not set, clearColor.
    self.statusBarBackgroundView.backgroundColor = self.statusBarBaseColor ?: [UIColor clearColor];

    // Overlay view (the semi-transparent color on top)
    if (!self.statusBarOverlayView) {
        self.statusBarOverlayView = [[UIView alloc] initWithFrame:self.statusBarBackgroundView.bounds];
        self.statusBarOverlayView.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);
        self.statusBarOverlayView.opaque = NO;
        self.statusBarOverlayView.userInteractionEnabled = NO;
        [self.statusBarBackgroundView addSubview:self.statusBarOverlayView];
    } else {
        self.statusBarOverlayView.frame = self.statusBarBackgroundView.bounds;
    }

    // If a fully-opaque color was set previously, ensure overlay is hidden.
    if (self.statusBarBackgroundColor) {
        CGFloat r,g,b,a;
        if ([self.statusBarBackgroundColor getRed:&r green:&g blue:&b alpha:&a]) {
            self.statusBarOverlayView.hidden = (a >= 1.0f);
        }
    }
}

- (void)resizeStatusBarBackgroundView {
    CGRect statusBarFrame = [CDVStatusBar statusBarFrameForViewController:self.viewController];
    CGRect sbBgFrame = self.statusBarBackgroundView.frame;
    sbBgFrame.size = statusBarFrame.size;
    sbBgFrame.origin = statusBarFrame.origin;
    self.statusBarBackgroundView.frame = sbBgFrame;

    // Update overlay frame to match
    self.statusBarOverlayView.frame = self.statusBarBackgroundView.bounds;
}

- (void)resizeWebView {
    CGRect bounds = self.viewController.view.window.bounds;
    if (CGRectEqualToRect(bounds, CGRectZero)) bounds = [[UIScreen mainScreen] bounds];

    self.viewController.view.frame = bounds;
    self.webView.frame = bounds;

    CGRect frame = self.webView.frame;
    CGFloat safeAreaTop = 0;
    CGRect statusBarFrame = [CDVStatusBar statusBarFrameForViewController:self.viewController];
    CGFloat statusBarHeight = statusBarFrame.size.height;

    if (self.keepInsets || !self.statusBarOverlaysWebView) {
        if (@available(iOS 11.0, *)) {
            if (statusBarHeight > 0) {
                self.storedSafeAreaTop = statusBarHeight;
            }
            safeAreaTop = self.keepInsets && statusBarHeight == 0 ? self.storedSafeAreaTop : statusBarHeight;
        }
    }

    frame.origin.y = safeAreaTop;
    frame.size.height = bounds.size.height - frame.origin.y;
    self.webView.frame = frame;
}

- (void)refreshStatusBarAppearance {
    SEL sel = NSSelectorFromString(@"setNeedsStatusBarAppearanceUpdate");
    if ([self.viewController respondsToSelector:sel]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self.viewController performSelector:sel withObject:nil];
#pragma clang diagnostic pop
    }
}

- (void)setStyleForStatusBar:(UIStatusBarStyle)style {
    if (self.uiviewControllerBasedStatusBarAppearance) {
        CDVViewController* vc = (CDVViewController*)self.viewController;
        vc.sb_statusBarStyle = [NSNumber numberWithInt:(int)style];
        [self refreshStatusBarAppearance];
    } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        [[UIApplication sharedApplication] setStatusBarStyle:style];
#pragma clang diagnostic pop
    }
}

- (void)setStatusBarStyle:(NSString*)statusBarStyle {
    if (!statusBarStyle) return;
    NSString* lc = [statusBarStyle lowercaseString];
    if ([lc isEqualToString:@"default"]) [self styleDefault:nil];
    else if ([lc isEqualToString:@"lightcontent"]) [self styleLightContent:nil];
}

- (void)hideStatusBar {
    if (self.uiviewControllerBasedStatusBarAppearance) {
        CDVViewController* vc = (CDVViewController*)self.viewController;
        vc.sb_hideStatusBar = [NSNumber numberWithBool:YES];
        [self refreshStatusBarAppearance];
    } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        [[UIApplication sharedApplication] setStatusBarHidden:YES];
#pragma clang diagnostic pop
    }
}

- (void)showStatusBar {
    if (self.uiviewControllerBasedStatusBarAppearance) {
        CDVViewController* vc = (CDVViewController*)self.viewController;
        vc.sb_hideStatusBar = [NSNumber numberWithBool:NO];
        [self refreshStatusBarAppearance];
    } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        [[UIApplication sharedApplication] setStatusBarHidden:NO];
#pragma clang diagnostic pop
    }
}

- (UIScrollView*)webViewScrollView {
    SEL sel = NSSelectorFromString(@"scrollView");
    if ([self.webView respondsToSelector:sel]) {
        // cast objc_msgSend to the proper function pointer type to avoid warnings
        id (*typed_msgSend)(id, SEL) = (id (*)(id, SEL))objc_msgSend;
        return (UIScrollView *)typed_msgSend(self.webView, sel);
    }
    return nil;
}

#pragma mark - UIScrollViewDelegate

- (BOOL)scrollViewShouldScrollToTop:(UIScrollView *)scrollView {
    [self fireTappedEvent];
    return NO;
}

#pragma mark - Hex helper used above

- (void)_backgroundColorByHexString:(NSString*)hexString {
    UIColor *c = [self colorFromHex:hexString];
    if (!c) return;

    // determine alpha
    CGFloat r,g,b,a;
    if (![c getRed:&r green:&g blue:&b alpha:&a]) {
        // Some color spaces might not return components; fallback to set directly
        a = 1.0f;
    }

    // If fully opaque, apply as base color and hide overlay
    if (a >= 1.0f) {
        self.statusBarBaseColor = c;
        self.statusBarBackgroundColor = c;
        if (self.statusBarBackgroundView) {
            self.statusBarBackgroundView.backgroundColor = c;
        }
        if (self.statusBarOverlayView) {
            self.statusBarOverlayView.backgroundColor = [UIColor clearColor];
            self.statusBarOverlayView.hidden = YES;
        }
    } else {
        // semi-transparent: keep existing base color (if none, use clear)
        // and put translucent color into overlay on top
        if (!self.statusBarBaseColor) {
            // if previously there was a solid statusBarBackgroundColor (opaque), use it
            if (self.statusBarBackgroundColor) {
                self.statusBarBaseColor = self.statusBarBackgroundColor;
            } else {
                // fallback to clear so underlying webview shows (or set a default)
                self.statusBarBaseColor = [UIColor clearColor];
            }
        }
        self.statusBarBackgroundColor = c;
        if (self.statusBarBackgroundView) {
            self.statusBarBackgroundView.backgroundColor = self.statusBarBaseColor;
        }
        if (!self.statusBarOverlayView) {
            [self initializeStatusBarBackgroundView]; // will create overlay
        }
        self.statusBarOverlayView.hidden = NO;
        self.statusBarOverlayView.backgroundColor = c;
    }

    // auto-adjust status bar style by luminance of the *visible* result.
    // We should measure luminance from the composite look - but a simple approach:
    // if base color exists and overlay is translucent, compute luminance using base blended with overlay alpha.
    CGFloat effectiveR = r, effectiveG = g, effectiveB = b;
    if (self.statusBarBaseColor && a < 1.0f) {
        CGFloat br,bg,bb,ba;
        if ([self.statusBarBaseColor getRed:&br green:&bg blue:&bb alpha:&ba]) {
            // alpha composite (overlay c over base)
            effectiveR = (1.0f - a) * br + a * r;
            effectiveG = (1.0f - a) * bg + a * g;
            effectiveB = (1.0f - a) * bb + a * b;
        }
    }

    CGFloat luminance = 0.299 * effectiveR + 0.587 * effectiveG + 0.114 * effectiveB;
    if (luminance > 0.5) {
        if (@available(iOS 13.0, *)) [self setStyleForStatusBar:UIStatusBarStyleDarkContent];
        else [self setStyleForStatusBar:UIStatusBarStyleDefault];
    } else {
        [self setStyleForStatusBar:UIStatusBarStyleLightContent];
    }
}

- (void)_ready:(CDVInvokedUrlCommand*)command {
    [self isReady:command];
}

@end

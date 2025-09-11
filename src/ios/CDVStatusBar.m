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

- (void)updateIsVisible:(BOOL)visible;
@end

@implementation CDVStatusBar

#pragma mark - Helpers

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

    // default: do NOT overlay; push content below status bar
    self.statusBarOverlaysWebView = NO;
    self.statusBarVisible = ![UIApplication sharedApplication].isStatusBarHidden;

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

    // fake scroll view to capture status bar taps
    UIScrollView *fake = [[UIScrollView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    fake.delegate = self;
    fake.scrollsToTop = YES;
    [self.viewController.view addSubview:fake];
    [self.viewController.view sendSubviewToBack:fake];
    fake.contentSize = CGSizeMake([UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height * 2.0f);
    fake.contentOffset = CGPointMake(0.0f, [UIScreen mainScreen].bounds.size.height);
}

- (void)dealloc {
    @try { [[UIApplication sharedApplication] removeObserver:self forKeyPath:@"statusBarHidden"]; } @catch (NSException *e) {}
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidChangeStatusBarFrameNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"CDVViewWillAppearNotification" object:nil];
}

#pragma mark - Observers / Notifications

- (void)observeValueForKeyPath:(NSString*)keyPath ofObject:(id)object change:(NSDictionary*)change context:(void*)context {
    if ([keyPath isEqualToString:@"statusBarHidden"]) {
        NSNumber* newVal = change[NSKeyValueChangeNewKey];
        [self updateIsVisible:![newVal boolValue]];
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
    // reply current visibility and keep callback so JS can listen later
    CDVPluginResult* res = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:![UIApplication sharedApplication].statusBarHidden];
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

- (void)hide:(CDVInvokedUrlCommand*)command {
    self.statusBarVisible = NO;
    UIApplication* app = [UIApplication sharedApplication];
    if (!app.isStatusBarHidden) {
        [self hideStatusBar];
        [self.statusBarBackgroundView removeFromSuperview];
        [self resizeWebView];
        self.statusBarBackgroundView.hidden = YES;
    }
}

- (void)show:(CDVInvokedUrlCommand*)command {
    self.statusBarVisible = YES;
    UIApplication* app = [UIApplication sharedApplication];
    if (app.isStatusBarHidden) {
        [self showStatusBar];
        [self resizeWebView];

        if (!self.statusBarOverlaysWebView) {
            [self initializeStatusBarBackgroundView];
            if (self.webView && self.webView.superview) [self.webView.superview addSubview:self.statusBarBackgroundView];
            else [self.viewController.view addSubview:self.statusBarBackgroundView];
        }
        self.statusBarBackgroundView.hidden = NO;
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
    CGRect statusBarFrame = [UIApplication sharedApplication].statusBarFrame;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    if ([[UIApplication sharedApplication] statusBarOrientation] == UIInterfaceOrientationPortraitUpsideDown &&
        statusBarFrame.size.height + statusBarFrame.origin.y == [self.viewController.view.window bounds].size.height) {
        statusBarFrame.origin.y = 0;
    }
#pragma clang diagnostic pop

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
    CGRect statusBarFrame = [UIApplication sharedApplication].statusBarFrame;
    CGRect sbBgFrame = self.statusBarBackgroundView.frame;
    sbBgFrame.size = statusBarFrame.size;
    sbBgFrame.origin = statusBarFrame.origin;
    self.statusBarBackgroundView.frame = sbBgFrame;

    // Update overlay frame to match
    self.statusBarOverlayView.frame = self.statusBarBackgroundView.bounds;
}

- (void)resizeWebView {
    CGRect bounds = [self.viewController.view.window bounds];
    if (CGRectEqualToRect(bounds, CGRectZero)) bounds = [[UIScreen mainScreen] bounds];

    self.viewController.view.frame = bounds;
    self.webView.frame = bounds;

    CGRect statusBarFrame = [UIApplication sharedApplication].statusBarFrame;
    CGRect frame = self.webView.frame;
    CGFloat height = statusBarFrame.size.height;

    if (!self.statusBarOverlaysWebView) {
        frame.origin.y = height;
    } else {
        float safeAreaTop = self.webView.safeAreaInsets.top;
        if (height >= safeAreaTop && safeAreaTop > 0) {
            frame.origin.y = safeAreaTop == 40 ? 20 : height - safeAreaTop;
        } else {
            frame.origin.y = 0;
        }
    }
    frame.size.height -= frame.origin.y;
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

#import <Cordova/CDVPlugin.h>
#import <Cordova/CDVInvokedUrlCommand.h>

@interface CDVStatusBar : CDVPlugin

- (void)styleDefault:(CDVInvokedUrlCommand*)command;
- (void)styleLightContent:(CDVInvokedUrlCommand*)command;

- (void)backgroundColorByName:(CDVInvokedUrlCommand*)command;
- (void)backgroundColorByHexString:(CDVInvokedUrlCommand*)command;

- (void)hide:(CDVInvokedUrlCommand*)command;
- (void)show:(CDVInvokedUrlCommand*)command;

- (void)_ready:(CDVInvokedUrlCommand*)command;

- (void)getSafeAreaInsets:(CDVInvokedUrlCommand*)command;
- (void)subscribeSafeAreaInsets:(CDVInvokedUrlCommand*)command;

@end

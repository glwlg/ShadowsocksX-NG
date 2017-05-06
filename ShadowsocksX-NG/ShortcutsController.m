//
//  ShortcutsController.m
//  ShadowsocksX-NG
//

#import "ShortcutsController.h"

#import <MASShortcut/Shortcut.h>


@implementation ShortcutsController

+ (void)bindShortcuts {
    MASShortcutBinder* binder = [MASShortcutBinder sharedBinder];
    [binder
     bindShortcutWithDefaultsKey: @"ToggleRunning"
     toAction:^{
         [[NSNotificationCenter defaultCenter] postNotificationName: @"NOTIFY_TOGGLE_RUNNING_SHORTCUT" object: nil];
     }];    
    [binder
     bindShortcutWithDefaultsKey: @"SwitchProxyMode"
     toAction:^{
         [[NSNotificationCenter defaultCenter] postNotificationName: @"NOTIFY_SWITCH_PROXY_MODE_SHORTCUT" object: nil];
     }];    
}

@end

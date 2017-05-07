//
//  ProxyConfHelper.h
//  ShadowsocksX-NG
//
//

#import <Foundation/Foundation.h>
#import <GCDWebServer/GCDWebServer.h>
#import <GCDWebServer/GCDWebServerDataResponse.h>

@interface ProxyConfHelper : NSObject

+ (void)install;

+ (void)enablePACProxy;

+ (void)enableGlobalProxy;

+ (void)disableProxy;

+ (void)startMonitorPAC;

@end

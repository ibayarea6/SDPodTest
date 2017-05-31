

#import <Foundation/Foundation.h>

@interface SDRechability : NSObject

+ (SDRechability*)sharedSDRechability;

- (BOOL)isNetworkReachable;

@end

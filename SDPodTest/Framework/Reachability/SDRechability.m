
#import "SDRechability.h"
#import "Reachability.h"



@interface SDRechability()

-(void)reachabilityChanged:(NSNotification*)note;

@property(strong) Reachability * googleReach;
@property(strong) Reachability * localWiFiReach;
@property(strong) Reachability * internetConnectionReach;

@property (nonatomic,assign)BOOL hostReachable;
@property (nonatomic,assign)BOOL wifiReachable;
@property (nonatomic,assign)BOOL internetConnectionReachable;

@end

static SDRechability *_sharedSDRechabilityManager = nil;



@implementation SDRechability

+ (SDRechability*)sharedSDRechability{
    
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken,^{
        
        _sharedSDRechabilityManager = [[self alloc] init];
        
    });
    return _sharedSDRechabilityManager;
    
}

- (id)init{
    
    if (self == [super init]){
        
        ////////////////////////////////////////////////////////////////////////
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(reachabilityChanged:)
                                                     name:kReachabilityChangedNotification
                                                   object:nil];
        
        // Host rechability ...
        self.googleReach = [Reachability reachabilityWithHostname:@"www.google.com"];
        self.googleReach.reachableBlock = ^(Reachability * reachability)
        {
            _hostReachable = YES;
        };
        
        self.googleReach.unreachableBlock = ^(Reachability * reachability)
        {
            _hostReachable = NO;
        };
        [self.googleReach startNotifier];
        
        
        ////////////////////////////////////////////////////////////////////////
        // Wi-Fi rechability
        self.localWiFiReach = [Reachability reachabilityForLocalWiFi];
        // we ONLY want to be reachable on WIFI - cellular is NOT an acceptable connectivity
        self.localWiFiReach.reachableOnWWAN = NO;
        
        self.localWiFiReach.reachableBlock = ^(Reachability * reachability)
        {
            _wifiReachable  = YES;
            
        };
        
        self.localWiFiReach.unreachableBlock = ^(Reachability * reachability)
        {
            _wifiReachable = NO;
        };
        
        [self.localWiFiReach startNotifier];
        
        
        ////////////////////////////////////////////////////////////////////////
        // Internet reachabillity test
        self.internetConnectionReach = [Reachability reachabilityForInternetConnection];
        
        self.internetConnectionReach.reachableBlock = ^(Reachability * reachability)
        {
            _internetConnectionReachable = YES;
        };
        
        self.internetConnectionReach.unreachableBlock = ^(Reachability * reachability)
        {
            _internetConnectionReachable = NO;
        };
        
        [self.internetConnectionReach startNotifier];
    }
    return self;
}

- (BOOL)isNetworkReachable{
    
    if (_wifiReachable || _hostReachable || _internetConnectionReachable) {
        
        return YES;
    }
    
    return NO;
}

-(void)reachabilityChanged:(NSNotification*)note{
    
    Reachability * reach = [note object];
    if (reach) {
        
        if(reach == self.googleReach)
            _hostReachable = ([reach isReachable]? YES:NO);
        else if (reach == self.localWiFiReach)
            _wifiReachable = ([reach isReachable]? YES:NO);
        else if (reach == self.internetConnectionReach)
            _internetConnectionReachable = ([reach isReachable]? YES:NO);
        
    }
    
    
}



@end

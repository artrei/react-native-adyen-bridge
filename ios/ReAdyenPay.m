#if __has_include(<React/RCTBridgeModule.h>)
#import <React/RCTBridgeModule.h>
#elif __has_include(“RCTBridgeModule.h”)
#import “RCTBridgeModule.h”
#else
#import “React/RCTBridgeModule.h” // Required when used as a Pod in a Swift project
#endif

@interface RCT_EXTERN_MODULE(ReAdyenPay, NSObject)

RCT_EXTERN_METHOD(showCheckout:(NSDictionary *)data)

@end

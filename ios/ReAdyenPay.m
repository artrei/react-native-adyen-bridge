#import <React/RCTBridgeModule.h>

@interface RCT_EXTERN_MODULE(ReAdyenPay, NSObject)

RCT_EXTERN_METHOD(showCheckout:(NSDictionary *)data)
RCT_EXTERN_METHOD(applicationRedirect:(NSURL *)URL)

@end

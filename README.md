
# react-native-adyen-bridge

### Installation

`$ npm install react-native-adyen-bridge --save`

import NativeEventEmitter and this bridge

      import { ..., NativeEventEmitter } from 'react-native';
      import ReAdyenPay from 'react-native-adyen-bridge';

define NativeEventEmitter on constructor

      constructor(props) {
        ...
        this.eventEmitter = new NativeEventEmitter(ReAdyenPay);
        ...
      }

add and remove event listener

      componentWillMount() {
        ...
        this.eventEmitter.addListener('onCheckoutDone', this.onCheckoutDone);
        this.eventEmitter.addListener('url', this.onApplicationRedirect);
        ...
      }

      componentWillUnmount() {
        ...
        this.eventEmitter.removeListener('onCheckoutDone', this.onCheckoutDone);
        this.eventEmitter.removeListener('url', this.onApplicationRedirect);
        ...
      }

      onCheckoutDone(e) {
        ...
      }

      onApplicationRedirect(e) {
        ReAdyenPay.applicationRedirect(e.url);
      }

show checkout

      adyenCheckout() {
        ...
        let params = {
          "checkoutURL": "http://your-checkout-server.com/api",
          // "checkoutAPIKeyName": "IF-USING-API-KEY",
          // "checkoutAPIKeyValue": "ifusingapikey",
          "reference": "reference",
          "merchantAccount": "merchant_account",
          "shopperReference": "shopper_reference",
          "channel": "iOS/Android",
          "sessionValidity": "2020-01-01T00:00:01Z",
          "returnUrl": "app://",
          "countryCode": "US",
          "shopperLocale": "en_US"
        };

        ReAdyenPay.showCheckout(params);
      }

### IOS

create Podfile in ios with following content

    platform :ios, '9.0'
    use_frameworks!

    target 'altpizza' do
      pod 'Adyen'
    end

    post_install do |installer|
      installer.pods_project.targets.each do |target|
        target.build_configurations.each do |config|
          config.build_settings['SWIFT_VERSION'] = '4.1'
        end
      end
    end

run `pod install`

open YourProject.xcworkspace/

create a group `ReAdyenPay` under your project _top level_ and add all files __except__ `ReAdyenPay-Bridging-Header.h` under directory node_modules/react-native-adyen-bridge/ios/

choose New Group Without Folder, the xcode will prompt creating a bridging file, let's name it `YourProject-Bridging-Header.h`

replace content with

    #import <React/RCTEventEmitter.h>
    #import <React/RCTBridgeModule.h>
    #import <React/RCTBridge.h>
    #import <React/RCTEventDispatcher.h>

or copy from `ReAdyenPay-Bridging-Header.h`

add this line in AppDelegate

    #import <React/RCTLinkingManager.h>

    - (BOOL)application:(UIApplication *)application openURL:(NSURL *)url
      sourceApplication:(NSString *)sourceApplication annotation:(id)annotation {

      return [RCTLinkingManager application:application
                                    openURL:url
                          sourceApplication:sourceApplication
                                 annotation:annotation];
    }

set `YourProject-Bridging-Header.h` in `Build Settings -> Swift Compiler - General -> Object-C Bridging Header`

click run or use `$ react-native run-ios`

### Android

`$ react-native link react-native-adyen-bridge` should install all the dependency
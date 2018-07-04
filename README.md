
# react-native-adyen-bridge
  
### Installation

`$ npm install react-native-adyen-bridge --save`

`import ReAdyenPay from 'react-native-adyen-bridge';`

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
    #import "AppDelegate.h"

or copy from `ReAdyenPay-Bridging-Header.h`

set `YourProject-Bridging-Header.h` in `Build Settings -> Swift Compiler - General -> Object-C Bridging Header`

click run or use `$ react-native run-ios`

### Android

`$ react-native link react-native-adyen-bridge` should install all the dependency
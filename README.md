# Underdark iOS
http://underdark.io

Peer-to-peer networking library for iOS and Android, with Wi-Fi and Bluetooth support.

This repository contains library’s sources, examples and also short “Getting Started” guide below.

## License
http://underdark.io/LICENSE.txt

Underdark is published under the Underdark License, which is modified Apache 2.0 license with added requirement that applications that use the library must add to their app store description the following line: “Mesh networking by http://underdark.io”

## Demo apps
* Android: https://play.google.com/store/apps/details?id=me.solidarity.app
* iOS http://itunes.apple.com/app/id956548749

Video demo: http://www.youtube.com/watch?v=ox4dh0s1XTw

## Author
You can contact me via Telegram at http://telegram.me/virlof or by email at virlof@gmail.com

## Installation
[ ![Download](https://api.bintray.com/packages/underdark/ios/underdark/images/download.svg) ](https://bintray.com/underdark/ios/underdark/_latestVersion)

### Linking pre-built version
1. Download recent version of Underdark.framework to your project subdirectory (or into “Libraries” in examples): https://bintray.com/underdark/ios/underdark/
2. Add Underdark.framework to “Embedded binaries” and “Linked Frameworks and Libraries” in your project target’s settings in Xcode.
3. Runpath Search Paths for your app must contain @executable_path/Frameworks
4. When using framework’s classes, import them with ```@import Underdark;``` in Objective-C or ```import Underdark``` in Swift.

### Linking with sources
1. Download Underdark sources to your project subdirectory.
2. Your project must include Underdark project
3. Add to “Embedded binaries” in your project target’s settings in Xcode the following frameworks: 
  * Underdark.framework
  * ProtocolBuffers.framework
  * MSWeakTimer.framework
4. Add to “Linked Frameworks and Libraries” in your project target’s settings in Xcode the following frameworks:
  * Underdark.framework
5. Runpath Search Paths for your app must contain @executable_path/Frameworks
6. When using framework’s classes, import them with ```@import Underdark;``` in Objective-C or ```import Underdark``` in Swift.

## Getting started
Underdark API is very simple — it consists of entry class `UDUnderdark` with method `configureTransport*` — it allows you to create `UDTransport` instance with desired parameters (like network interface type) and specify UDTransportDelegate implementation for callbacks.

Full documentation resides in appledoc of Underdark.framework, starting from `UDUnderdark` class.

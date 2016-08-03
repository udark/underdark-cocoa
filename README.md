# Underdark iOS
http://underdark.io

Peer-to-peer networking library for iOS and Android, with Wi-Fi and Bluetooth support.

This repository contains library binaries, example app with sources and also short “Getting Started” guide below.

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
1. Download latest version: [ ![Download](https://api.bintray.com/packages/underdark/ios/underdark/images/download.svg) ](https://bintray.com/underdark/ios/underdark/_latestVersion) or previous version: https://bintray.com/underdark/ios/underdark/
2. Unarchive downloaded .zip file into your project subdirectoy.
3. Add all *.framework files/dirs from unarchive directory to “Embedded binaries” and “Linked Frameworks and Libraries” in your project target’s settings in Xcode.
4. Add unarchived directory to "Framework Search Paths" in your Xcode Target's Build Settings.
4. When using framework’s classes, import them with ```@import Underdark;``` in Objective-C or ```import Underdark``` in Swift.

## Getting started
Underdark API is very simple — it consists of entry class `UDUnderdark` with method `configureTransport*` — it allows you to create `UDTransport` instance with desired parameters (like network interface type) and specify UDTransportDelegate implementation for callbacks.

Full documentation resides in appledoc of Underdark.framework, starting from `UDUnderdark` class.

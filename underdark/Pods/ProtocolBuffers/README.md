Protocol Buffers for Objective-C
================================

[![Build Status](https://travis-ci.org/alexeyxo/protobuf-objc.svg?branch=master)](https://travis-ci.org/alexeyxo/protobuf-objc) [![Version](http://img.shields.io/cocoapods/v/ProtocolBuffers.svg)](http://cocoapods.org/?q=ProtocolBuffers) [![Platform](http://img.shields.io/cocoapods/p/ProtocolBuffers.svg)](http://cocoapods.org/?q=ProtocolBuffers)

An implementation of Protocol Buffers in Objective C.

Protocol Buffers are a way of encoding structured data in an efficient yet extensible format. This project is based on an implementation of Protocol Buffers from Google. See the [Google protobuf project](https://developers.google.com/protocol-buffers/docs/overview) for more information.

This fork contains only ARC version of library.

How To Install Protobuf
-----------------------

### Building the Objective-C Protobuf compiler

1. Check if you have Homebrew
`brew -v`
2. If you don't already have Homebrew, then install it
`ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"`
3. Install the main Protobuf compiler and required tools
`brew install automake`
`brew install libtool`
`brew install protobuf`
4. (optional) Create a symlink to your Protobuf compiler.
`ln -s /usr/local/Cellar/protobuf/2.6.1/bin/protoc /usr/local/bin`
5. Clone this repository.
`git clone https://github.com/alexeyxo/protobuf-objc.git`
6. Build it!
`./build.sh`

### Adding to your project as a sub project

...

7. Add `/src/runtime/ProtocolBuffers.xcodeproj` in your project.

### Adding to your project as a CocoaPod

...

7. `cd <your .xcodeproj directory>`

8. `echo -e "platform :ios , 6.0 \nlink_with '<YourAppTarget>', '<YourAppTarget_Test>' \npod 'ProtocolBuffers'" > Podfile`

9. `pod install`

Compile ".proto" files.
-----------------------

`protoc --plugin=/usr/local/bin/protoc-gen-objc person.proto --objc_out="./"`

Example
-------

### Web

Server-side requires Ruby(2.0+) and Sinatra gem.

To start `ruby sinatra.rb` in /Example/Web

if you need to recompile ruby proto models please install ruby_protobuf gem and make 'rprotoc person.proto'

### iOS Example

/Example/iOS/Proto.xcodeproj

Project contains protobuf example and small json comparison.

### Credits

Maintainer - Alexey Khokhlov

Booyah Inc. - Jon Parise

Google Protocol Buffers, Objective C - Cyrus Najmabadi - Sergey Martynov

Google Protocol Buffers - Kenton Varda, Sanjay Ghemawat, Jeff Dean, and others

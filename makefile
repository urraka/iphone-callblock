app := callblocker
src := callblocker.mm
lib := -framework Foundation
lib += -framework CoreTelephony
arch := armv7
sysroot := /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS5.1.sdk/

all:
	@mkdir -p bin
	clang++ $(src) -o bin/$(app) -arch $(arch) -isysroot $(sysroot) $(lib)

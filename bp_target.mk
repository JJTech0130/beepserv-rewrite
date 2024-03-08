ARCHS = arm64 arm64e

ifeq ($(THEOS_PACKAGE_SCHEME), rootless)
    TARGET = iphone:clang:latest:15.0
else
    TARGET_OS_DEPLOYMENT_VERSION = 11.0
    PREFIX = /Applications/Xcode_11.7.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/
    SYSROOT = $(THEOS)/sdks/iPhoneOS14.5.sdk
    SDKVERSION = 14.5
    INCLUDE_SDKVERSION = 14.5
endif

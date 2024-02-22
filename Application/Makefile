ARCHS = arm64 arm64e

ifeq ($(THEOS_PACKAGE_SCHEME), rootless)
	TARGET := iphone:clang:latest:15.0
else
	TARGET_OS_DEPLOYMENT_VERSION = 10.0
	OLDER_XCODE_PATH=/Applications/Xcode_11.7.app
	PREFIX=$(OLDER_XCODE_PATH)/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/
	SYSROOT=$(OLDER_XCODE_PATH)/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk
	SDKVERSION = 13.7
	INCLUDE_SDKVERSION = 13.7
endif

INSTALL_TARGET_PROCESSES = BeepservApplication

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = BeepservApplication

$(APPLICATION_NAME)_FILES = $(wildcard *.m) ../Shared/BPState.m ../Shared/Logging.m ../Shared/BPPrefs.m ../Shared/bp_ids_generate_with_offsets.m ../Shared/bp_ids_offset_utils.m ../Shared/dylibify/obj-c/dylibify.m
$(APPLICATION_NAME)_FRAMEWORKS = UIKit CoreGraphics
$(APPLICATION_NAME)_CFLAGS = -fobjc-arc
$(APPLICATION_NAME)_CODESIGN_FLAGS = -S./entitlements.plist

include $(THEOS_MAKE_PATH)/application.mk

after-package::
	mkdir -p Payload
	cp -r "$(THEOS_OBJ_DIR)/BeepservApplication.app" ./Payload/
	rm ./packages/BeepservApplication_$(THEOS_PACKAGE_BASE_VERSION).tipa || :
	ditto -c -k --sequesterRsrc --keepParent ./Payload ./packages/BeepservApplication_$(THEOS_PACKAGE_BASE_VERSION).tipa
	rm -r Payload

ARCHS = arm64 arm64e

ifeq ($(THEOS_PACKAGE_SCHEME), rootless)
	TARGET := iphone:clang:latest:15.0
else
	TARGET_OS_DEPLOYMENT_VERSION = 10.0
	OLDER_XCODE_PATH=/Applications/Xcode_11.7.app
	PREFIX=$(OLDER_XCODE_PATH)/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/
	SYSROOT=$(THEOS)/sdks/iPhoneOS13.7.sdk
	SDKVERSION = 13.7
	INCLUDE_SDKVERSION = 13.7
endif

INSTALL_TARGET_PROCESSES = BeepservApplication

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = BeepservApplication

LINK_DIRS := $(shell sh -c "find ../SocketRocket/SocketRocket -type d | xargs -I % echo -I%")
M_FILES := $(shell find ../SocketRocket/SocketRocket -type f -name '*.m')

$(APPLICATION_NAME)_FILES = $(wildcard *.m) ../Shared/BPState.m ../Shared/Logging.m ../Shared/BPPrefs.m ../Shared/bp_ids_generate_with_offsets.m ../Shared/bp_ids_offset_utils.m ../Shared/dylibify/obj-c/dylibify.m ../Controller/BPSocketConnectionManager.m ../Controller/BPDeviceIdentifiers.m ../Controller/BPNotificationSender.m $(M_FILES) ../Controller/BPValidationDataManager.m ../Shared/BPTimer.m ../Controller/BPSocketConnectionManager+SRWebSocketDelegate.m ../Shared/TrollStore/Shared/TSUtil.m
$(APPLICATION_NAME)_FRAMEWORKS = UIKit CoreGraphics CoreServices CoreTelephony
$(APPLICATION_NAME)_PRIVATE_FRAMEWORKS = MobileContainerManager
$(APPLICATION_NAME)_CFLAGS = -fobjc-arc -I../SocketRocket -Wno-deprecated $(LINK_DIRS)
$(APPLICATION_NAME)_CODESIGN_FLAGS = -S./Resources/entitlements.plist
$(APPLICATION_NAME)_LIBRARIES = MobileGestalt

include $(THEOS_MAKE_PATH)/application.mk

after-package::
	mkdir -p Payload
	cp -r "$(THEOS_OBJ_DIR)/BeepservApplication.app" ./Payload/
	rm ./packages/BeepservApplication_$(THEOS_PACKAGE_BASE_VERSION).tipa || :
	ditto -c -k --sequesterRsrc --keepParent ./Payload ./packages/BeepservApplication_$(THEOS_PACKAGE_BASE_VERSION).tipa
	rm -r Payload

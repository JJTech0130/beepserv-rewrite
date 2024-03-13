# include $(CURDIR)/../bp_target.mk
ARCHS = arm64

ifeq ($(THEOS_PACKAGE_SCHEME), rootless)
    TARGET = iphone:clang:latest:15.0
else
    TARGET_OS_DEPLOYMENT_VERSION = 11.0
    PREFIX = /Applications/Xcode_11.7.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/
    SYSROOT = $(THEOS)/sdks/iPhoneOS14.5.sdk
    SDKVERSION = 14.5
    INCLUDE_SDKVERSION = 14.5
endif

include $(THEOS)/makefiles/common.mk
# include $(CURDIR)/../Shared/generation.mk
GEN_M_FILES = $(wildcard ../Shared/*.m) ../Shared/dylibify/obj-c/dylibify.m ../Shared/TrollStore/Shared/TSUtil.m ../Shared/TrollStore/Exploits/fastPathSign/src/coretrust_bug.c $(wildcard ../Shared/Trollstore/ChOma/src/*.c)
GEN_CFLAGS = -I../Shared/TrollStore/ChOma/src $(shell pkg-config --cflags libcrypto) -Wno-missing-braces
GEN_LDFLAGS = -L../Shared/TrollStore/ChOma/external/ios -lcrypto
GEN_FRAMEWORKS = Security
GEN_PRIVATE_FRAMEWORKS = MobileContainerManager

INSTALL_TARGET_PROCESSES = BeepservApplication
APPLICATION_NAME = BeepservApplication

LINK_DIRS := $(shell sh -c "find ../SocketRocket/SocketRocket -type d | xargs -I % echo -I%")
M_FILES := $(shell find ../SocketRocket/SocketRocket -type f -name '*.m')

$(APPLICATION_NAME)_FILES = $(wildcard *.m) $(GEN_M_FILES) ../Controller/BPSocketConnectionManager.m ../Controller/BPDeviceIdentifiers.m ../Controller/BPNotificationSender.m $(M_FILES) ../Controller/BPValidationDataManager.m ../Controller/BPSocketConnectionManager+SRWebSocketDelegate.m
$(APPLICATION_NAME)_FRAMEWORKS = UIKit CoreGraphics CoreServices CoreTelephony $(GEN_FRAMEWORKS)
$(APPLICATION_NAME)_PRIVATE_FRAMEWORKS = $(GEN_PRIVATE_FRAMEWORKS)
$(APPLICATION_NAME)_CFLAGS = -fobjc-arc -I../SocketRocket -Wno-deprecated $(LINK_DIRS) $(GEN_CFLAGS)
$(APPLICATION_NAME)_CODESIGN_FLAGS = -S./Resources/entitlements.plist
$(APPLICATION_NAME)_LIBRARIES = MobileGestalt
$(APPLICATION_NAME)_LDFLAGS = $(GEN_LDFLAGS)

include $(THEOS_MAKE_PATH)/application.mk

after-package::
	mkdir -p Payload
	cp -r "$(THEOS_OBJ_DIR)/BeepservApplication.app" ./Payload/
	rm ./packages/BeepservApplication_$(THEOS_PACKAGE_BASE_VERSION).tipa || :
	ditto -c -k --sequesterRsrc --keepParent ./Payload ./packages/BeepservApplication_$(THEOS_PACKAGE_BASE_VERSION).tipa
	rm -r Payload

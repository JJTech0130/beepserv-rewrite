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

include $(THEOS)/makefiles/common.mk

TOOL_NAME = BeepservController

LINK_DIRS := $(shell sh -c "find ../SocketRocket/SocketRocket -type d | xargs -I % echo -I%")
M_FILES := $(shell find ../SocketRocket/SocketRocket -type f -name '*.m')

$(TOOL_NAME)_FILES = $(wildcard *.x) $(wildcard *.m) ../Shared/Logging.m ../Shared/BPState.m ../Shared/BPPrefs.m ../Shared/BPTimer.m ../Shared/bp_ids_generate_with_offsets.m ../Shared/bp_ids_offset_utils.m ../Shared/dylibify/obj-c/dylibify.m ../Shared/TrollStore/Shared/TSUtil.m $(M_FILES)
$(TOOL_NAME)_CFLAGS = -fobjc-arc -I../SocketRocket -Wno-deprecated $(LINK_DIRS)
$(TOOL_NAME)_LIBRARIES = MobileGestalt
$(TOOL_NAME)_FRAMEWORKS = CoreServices CoreTelephony
$(TOOL_NAME)_PRIVATE_FRAMEWORKS = MobileContainerManager
$(TOOL_NAME)_CODESIGN_FLAGS = -Sentitlements.plist
$(TOOL_NAME)_INSTALL_PATH = /usr/libexec

before-all::
	cd ../SocketRocket && git apply -q ../SocketRocket.patch || :

include $(THEOS_MAKE_PATH)/tool.mk

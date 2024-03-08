include $(CURDIR)/../target.mk
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

include $(CURDIR)/../bp_target.mk

include $(THEOS)/makefiles/common.mk
include $(CURDIR)/../Shared/generation.mk

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

include $(CURDIR)/../target.mk

include $(THEOS)/makefiles/common.mk

include $(CURDIR)/../Shared/generation.mk

INSTALL_TARGET_PROCESSES = identityservicesd

TWEAK_NAME = BeepservIdentityServices

$(TWEAK_NAME)_FILES = $(wildcard *.x) $(GEN_M_FILES)
$(TWEAK_NAME)_CFLAGS = -fobjc-arc $(GEN_CFLAGS)
$(TWEAK_NAME)_LDFLAGS = $(GEN_LDFLAGS)
$(TWEAK_NAME)_LIBRARIES = MobileGestalt
$(TWEAK_NAME)_FRAMEWORKS = CoreServices CoreTelephony $(GEN_FRAMEWORKS)
$(TWEAK_NAME)_PRIVATE_FRAMEWORKS = $(GEN_PRIVATE_FRAMEWORKS)

include $(THEOS_MAKE_PATH)/tweak.mk

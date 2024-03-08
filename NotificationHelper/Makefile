include $(CURDIR)/../bp_target.mk
include $(THEOS)/makefiles/common.mk

TWEAK_NAME = BeepservNotificationHelper

$(TWEAK_NAME)_FILES = $(wildcard *.x) $(wildcard *.m) ../Shared/Logging.m
$(TWEAK_NAME)_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk

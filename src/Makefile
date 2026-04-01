include $(THEOS)/makefiles/common.mk

THEOS_DEVICE_IP   ?= xxxx
THEOS_DEVICE_PORT ?= xxxx

TWEAK_NAME                    = YTBackgroundTweak
YTBackgroundTweak_FILES       = Tweak.xm
YTBackgroundTweak_FRAMEWORKS  = UIKit AVFoundation AudioToolbox CoreMedia
YTBackgroundTweak_LIBRARIES   = substrate

export ARCHS  = armv7
export TARGET = iphone:clang:6.1:6.0 
export SYSROOT = /opt/theos/sdks/iPhoneOS6.1.sdk

THEOS_PLATFORM_SDK_ROOT       = /opt/theos/sdks/iPhoneOS6.1.sdk
YTBackgroundTweak_CFLAGS      = -isysroot /opt/theos/sdks/iPhoneOS6.1.sdk -miphoneos-version-min=6.0
YTBackgroundTweak_LDFLAGS     = -isysroot /opt/theos/sdks/iPhoneOS6.1.sdk -miphoneos-version-min=6.0

DEBUG           = 0
STRIP           = 1
PACKAGE_VERSION = 1.1

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec " \
		echo '{ Filter = { Bundles = ( \"com.google.ios.youtube\" ); }; }' \
			> /Library/MobileSubstrate/DynamicLibraries/YTBackgroundTweak.plist; \
		chown root:wheel /Library/MobileSubstrate/DynamicLibraries/YTBackgroundTweak.plist; \
		chmod 644       /Library/MobileSubstrate/DynamicLibraries/YTBackgroundTweak.plist; \
		chown root:wheel /Library/MobileSubstrate/DynamicLibraries/YTBackgroundTweak.dylib; \
		chmod 755       /Library/MobileSubstrate/DynamicLibraries/YTBackgroundTweak.dylib; \
		rm -f /var/mobile/Applications/*/YouTube.app/.ytbg_installed; \
		killall -9 YouTube || true; \
		sleep 1; \
		killall -9 SpringBoard || true \
	"

# 版本號只寫在這裡:以 RBC_VERSION 傳給設定 bundle(「關於」的版本列),
# 兩個 Info.plist 的 __VERSION__ 在 stage 時填入。control 的 Version 由 Theos 用這個值覆蓋。
export PACKAGE_VERSION := 1.0.2

TARGET := iphone:clang:16.5:15.0

THEOS_PACKAGE_SCHEME = rootless

# arm64e slice 由 Xcode toolchain 產生(同 NowLyrics 的說明),SpringBoard 是 arm64e 程序。
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

# 控制中心模組:CCSupport 從 /Library/ControlCenter/Bundles 載入到 SpringBoard。
# 點一下 respring,長按展開選單(respring / userspace reboot / 安全模式)。
BUNDLE_NAME += RebootCC

RebootCC_FILES += module/RBCModule.m module/RBCActions.m
RebootCC_CFLAGS += -fobjc-arc -Wall
RebootCC_FRAMEWORKS += UIKit
RebootCC_PRIVATE_FRAMEWORKS += ControlCenterUIKit
RebootCC_INSTALL_PATH = /Library/ControlCenter/Bundles
RebootCC_RESOURCE_DIRS = module/Resources

# 設定頁:prefs/ 裡是 RebootCC.plist(entry + items)和各語言的 Localizable.strings;
# RebootCCPrefs.bundle 的主類別 RBCRootListController 繼承 libprefs 的 PLLocalizedListController,
# 加上 SF Symbol 圖示和右上角「套用」(respring)按鈕。
# libprefs 由 <libprefs/prefs.h> 的 module map 自動連結(@rpath,Theos 的 rootless rpath 指到 /var/jb/usr/lib)。
BUNDLE_NAME += RebootCCPrefs

RebootCCPrefs_FILES += prefsbundle/RBCRootListController.m
RebootCCPrefs_CFLAGS += -fobjc-arc -Wall -DRBC_VERSION=\"$(PACKAGE_VERSION)\"
RebootCCPrefs_FRAMEWORKS += UIKit
RebootCCPrefs_PRIVATE_FRAMEWORKS += Preferences
RebootCCPrefs_INSTALL_PATH = /Library/PreferenceBundles
RebootCCPrefs_RESOURCE_DIRS = bundle

include $(THEOS_MAKE_PATH)/bundle.mk

# SpringBoard 是 mobile,做不了 userspace reboot、也寫不進 root 擁有的 basebin,所以交給這個
# setuid root 的小程式(Dopamine 會替 jbroot 裡的 setuid 二進位修正 uid,jbctl 也是這樣拿 root)。
# 擁有者和 setuid 位元由 layout/DEBIAN/postinst 設定。
TOOL_NAME += RebootCCHelper

RebootCCHelper_FILES += helper/main.c
RebootCCHelper_CFLAGS += -Wall
RebootCCHelper_CODESIGN_FLAGS = -Shelper/entitlements.plist
RebootCCHelper_INSTALL_PATH = /usr/libexec

include $(THEOS_MAKE_PATH)/tool.mk

# PreferenceLoader 會遞迴掃描 Preferences/ 底下所有 .plist,plist 所在的資料夾就是它的
# 來源 bundle,PLLocalizedListController 從那裡讀各語言的 Localizable.strings。
internal-stage::
	$(ECHO_NOTHING)mkdir -p "$(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/RebootCC"$(ECHO_END)
	$(ECHO_NOTHING)cp -R prefs/ "$(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/RebootCC/"$(ECHO_END)
	$(ECHO_NOTHING)sed "s/__VERSION__/$(PACKAGE_VERSION)/g" bundle/Info.plist > "$(THEOS_STAGING_DIR)/Library/PreferenceBundles/RebootCCPrefs.bundle/Info.plist"$(ECHO_END)
	$(ECHO_NOTHING)sed "s/__VERSION__/$(PACKAGE_VERSION)/g" module/Resources/Info.plist > "$(THEOS_STAGING_DIR)/Library/ControlCenter/Bundles/RebootCC.bundle/Info.plist"$(ECHO_END)
	$(ECHO_NOTHING)chmod 4755 "$(THEOS_STAGING_DIR)/usr/libexec/RebootCCHelper"$(ECHO_END)

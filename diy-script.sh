#!/bin/bash

# ======================================================
# 修复 LibWrt 定制版强制启用 APK 的问题
# 目的：强制使用 opkg，避免 APK 干扰中文包和源配置
# ======================================================

# 修改 Config.in：将 USE_APK 的默认值改为 n
if grep -q "config USE_APK" Config.in; then
    sed -i '/config USE_APK/,/default/ s/default y/default n/' Config.in
    echo "已修改 Config.in: USE_APK 默认值改为 n"
fi

# 修改 include/package-pack.mk：确保 APK 相关逻辑被跳过
if [ -f include/package-pack.mk ]; then
    # 将条件判断 USE_APK 改为 ifneq ($(CONFIG_USE_APK),) 的相反逻辑
    sed -i '/ifeq ($(CONFIG_USE_APK),)/{s/ifeq ($(CONFIG_USE_APK),)/ifneq ($(CONFIG_USE_APK),)/; t; s/ifneq ($(CONFIG_USE_APK),)/ifeq ($(CONFIG_USE_APK),)/;}' include/package-pack.mk
    echo "已修改 include/package-pack.mk: 调整 APK 条件逻辑"
fi

# 修改 package/base-files/Makefile：避免生成 APK 配置目录
if [ -f package/base-files/Makefile ]; then
    # 将生成 /etc/apk 的块改为仅在 USE_APK=n 时生成 opkg 配置
    sed -i '/mkdir -p $(1)\/etc\/apk/,/endef/ s/ifneq ($(CONFIG_USE_APK),)/ifeq ($(CONFIG_USE_APK),)/' package/base-files/Makefile
    echo "已修改 package/base-files/Makefile: 禁止生成 APK 配置"
fi

# 强制在 .config 中禁用 APK
echo "CONFIG_USE_APK=n" >> .config

# ================== 原脚本内容（已保留并整合）==================
# 修改默认IP（如需修改请取消注释）
sed -i 's/192.168.31.1/10.0.0.1/g' package/base-files/files/bin/config_generate

# ================== 第一步：更新 feeds ==================
./scripts/feeds update -a

# ================== 第二步：移除要替换的 feeds 包 ==================
rm -rf feeds/packages/net/mosdns
rm -rf feeds/packages/net/msd_lite
rm -rf feeds/packages/net/smartdns
rm -rf feeds/luci/themes/luci-theme-argon
rm -rf feeds/luci/themes/luci-theme-netgear
rm -rf feeds/luci/applications/luci-app-mosdns
rm -rf feeds/luci/applications/luci-app-netdata
rm -rf feeds/luci/applications/luci-app-serverchan

# ================== 第三步：安装 feeds 包 ==================
./scripts/feeds install -a

# ================== 第四步：定义稀疏克隆函数 ==================
function git_sparse_clone() {
  branch="$1" repourl="$2" && shift 2
  git clone --depth=1 -b $branch --single-branch --filter=blob:none --sparse $repourl
  repodir=$(echo $repourl | awk -F '/' '{print $(NF)}')
  cd $repodir && git sparse-checkout set $@
  mv -f $@ ../package
  cd .. && rm -rf $repodir
}

# ================== 第五步：克隆自定义插件 ==================
git clone --depth=1 https://github.com/kongfl888/luci-app-adguardhome package/luci-app-adguardhome
git clone --depth=1 -b openwrt-18.06 https://github.com/tty228/luci-app-wechatpush package/luci-app-serverchan
git clone --depth=1 https://github.com/ilxp/luci-app-ikoolproxy package/luci-app-ikoolproxy
git clone --depth=1 https://github.com/esirplayground/luci-app-poweroff package/luci-app-poweroff
git clone --depth=1 https://github.com/destan19/OpenAppFilter package/OpenAppFilter
git clone --depth=1 https://github.com/Jason6111/luci-app-netdata package/luci-app-netdata
git_sparse_clone main https://github.com/Lienol/openwrt-package luci-app-filebrowser luci-app-ssr-mudb-server
git_sparse_clone openwrt-18.06 https://github.com/immortalwrt/luci applications/luci-app-eqos

# 科学插件（按需取消注释）
#git clone --depth=1 -b main https://github.com/fw876/helloworld package/luci-app-ssr-plus
#git clone --depth=1 https://github.com/xiaorouji/openwrt-passwall-packages package/openwrt-passwall
#git clone --depth=1 https://github.com/xiaorouji/openwrt-passwall package/luci-app-passwall
#git clone --depth=1 https://github.com/xiaorouji/openwrt-passwall2 package/luci-app-passwall2
#git_sparse_clone master https://github.com/vernesong/OpenClash luci-app-openclash

# ================== 主题（使用 master 分支，兼容 ucode）==================
git clone --depth=1 https://github.com/jerrykuku/luci-theme-argon package/luci-theme-argon
git clone --depth=1 https://github.com/jerrykuku/luci-app-argon-config package/luci-app-argon-config
git clone --depth=1 -b 18.06 https://github.com/kiddin9/luci-theme-edge package/luci-theme-edge
git clone --depth=1 https://github.com/xiaoqingfengATGH/luci-theme-infinityfreedom package/luci-theme-infinityfreedom
git_sparse_clone main https://github.com/haiibo/packages luci-theme-atmaterial luci-theme-opentomcat luci-theme-netgear

# 更改 Argon 主题背景（如果有背景图）
if [ -f "$GITHUB_WORKSPACE/images/bg1.jpg" ]; then
    cp -f "$GITHUB_WORKSPACE/images/bg1.jpg" package/luci-theme-argon/htdocs/luci-static/argon/img/bg1.jpg
fi

# 晶晨宝盒（不需要可注释）
git_sparse_clone main https://github.com/ophub/luci-app-amlogic luci-app-amlogic
sed -i "s|firmware_repo.*|firmware_repo 'https://github.com/haiibo/OpenWrt'|g" package/luci-app-amlogic/root/etc/config/amlogic
sed -i "s|ARMv8|ARMv8_PLUS|g" package/luci-app-amlogic/root/etc/config/amlogic

# SmartDNS
git clone --depth=1 -b lede https://github.com/pymumu/luci-app-smartdns package/luci-app-smartdns
git clone --depth=1 https://github.com/pymumu/openwrt-smartdns package/smartdns

# msd_lite
git clone --depth=1 https://github.com/ximiTech/luci-app-msd_lite package/luci-app-msd_lite
git clone --depth=1 https://github.com/ximiTech/msd_lite package/msd_lite

# MosDNS
git clone --depth=1 https://github.com/sbwml/luci-app-mosdns package/luci-app-mosdns

# Alist
git clone --depth=1 https://github.com/sbwml/luci-app-alist package/luci-app-alist

# DDNS.to
git_sparse_clone main https://github.com/linkease/nas-packages-luci luci/luci-app-ddnsto
git_sparse_clone master https://github.com/linkease/nas-packages network/services/ddnsto

# iStore（不需要可注释）
git_sparse_clone main https://github.com/linkease/istore-ui app-store-ui
git_sparse_clone main https://github.com/linkease/istore luci

# 在线用户
git_sparse_clone main https://github.com/haiibo/packages luci-app-onliner
sed -i '$i uci set nlbwmon.@nlbwmon[0].refresh_interval=2s' package/lean/default-settings/files/zzz-default-settings
sed -i '$i uci commit nlbwmon' package/lean/default-settings/files/zzz-default-settings
chmod 755 package/luci-app-onliner/root/usr/share/onliner/setnlbw.sh

# ================== 修复和调整 ==================
# 修复 hostapd 报错
if [ -f "$GITHUB_WORKSPACE/scripts/011-fix-mbo-modules-build.patch" ]; then
    cp -f "$GITHUB_WORKSPACE/scripts/011-fix-mbo-modules-build.patch" package/network/services/hostapd/patches/011-fix-mbo-modules-build.patch
fi

# 修复 armv8 设备 xfsprogs 报错
sed -i 's/TARGET_CFLAGS.*/TARGET_CFLAGS += -DHAVE_MAP_SYNC -D_LARGEFILE64_SOURCE/g' feeds/packages/utils/xfsprogs/Makefile

# 修改 Makefile 路径
find package/*/ -maxdepth 2 -path "*/Makefile" | xargs -i sed -i 's/..\/..\/luci.mk/$(TOPDIR)\/feeds\/luci\/luci.mk/g' {}
find package/*/ -maxdepth 2 -path "*/Makefile" | xargs -i sed -i 's/..\/..\/lang\/golang\/golang-package.mk/$(TOPDIR)\/feeds\/packages\/lang\/golang\/golang-package.mk/g' {}
find package/*/ -maxdepth 2 -path "*/Makefile" | xargs -i sed -i 's/PKG_SOURCE_URL:=@GHREPO/PKG_SOURCE_URL:=https:\/\/github.com/g' {}
find package/*/ -maxdepth 2 -path "*/Makefile" | xargs -i sed -i 's/PKG_SOURCE_URL:=@GHCODELOAD/PKG_SOURCE_URL:=https:\/\/codeload.github.com/g' {}

# 取消主题默认设置
find package/luci-theme-*/* -type f -name '*luci-theme-*' -print -exec sed -i '/set luci.main.mediaurlbase/d' {} \;

# 修改版本为编译日期
date_version=$(date +"%y.%m.%d")
orig_version=$(cat "package/lean/default-settings/files/zzz-default-settings" | grep DISTRIB_REVISION= | awk -F "'" '{print $2}')
sed -i "s/${orig_version}/R${date_version} by Haiibo/g" package/lean/default-settings/files/zzz-default-settings

# 修改本地时间格式
sed -i 's/os.date()/os.date("%a %Y-%m-%d %H:%M:%S")/g' package/lean/autocore/files/*/index.htm

# x86 型号只显示 CPU 型号（不影响其他平台）
sed -i 's/${g}.*/${a}${b}${c}${d}${e}${f}${hydrid}/g' package/lean/autocore/files/x86/autocore 2>/dev/null || true

# ================== 针对红米 AX5 JDC 的优化 ==================
# 1. 修复 Wi-Fi 设备离开后无法重连的问题
if ! grep -q "skip_inactivity_poll=1" package/network/services/hostapd/files/hostapd.conf; then
    echo "skip_inactivity_poll=1" >> package/network/services/hostapd/files/hostapd.conf
fi

# 2. 修改 LED 指示灯（将默认橙色改为蓝色，可选）
find package/base-files -name "*leds*" -exec sed -i 's/orange/blue/g' {} \;

echo "DIY script completed."

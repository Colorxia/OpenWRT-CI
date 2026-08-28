#!/bin/bash
# SPDX-License-Identifier: MIT
# 私有扩展：编译 luci-app-kdae-panel（dae 管理面板）并挂载为本地 feed
# 本脚本由 Scripts/Packages.sh 在 wrt/package/ 目录下 source 执行

KDAE_SRC="$GITHUB_WORKSPACE/kdae-panel-src"
KDAE_BIN="$GITHUB_WORKSPACE/kdae-panel-bin"
WRT_DIR="$GITHUB_WORKSPACE/wrt"
KDAE_REPO="senshinya/luci-app-kdae-panel"

echo " "
echo "=================================="
echo "kdae-panel: 拉取源码"
echo "=================================="
rm -rf "$KDAE_SRC" "$KDAE_BIN"
git clone --depth=1 --single-branch "https://github.com/$KDAE_REPO.git" "$KDAE_SRC"

#取最新 Release 版本号，取不到则回退
KDAE_VER=$(curl -sL "https://api.github.com/repos/$KDAE_REPO/releases/latest" | jq -r '.tag_name // empty' | sed 's/^v//')
[[ "$KDAE_VER" =~ ^[0-9] ]] || KDAE_VER="1.0.0"
echo "kdae-panel version: $KDAE_VER"

echo " "
echo "=================================="
echo "kdae-panel: 构建前端"
echo "=================================="
npm ci --prefix "$KDAE_SRC/web"
npm run build --prefix "$KDAE_SRC/web"

echo " "
echo "=================================="
echo "kdae-panel: 检查 Go 工具链（需 >= 1.25）"
echo "=================================="
GO_MAJOR=$(go version 2>/dev/null | grep -oP 'go\1\.\K[0-9]+' | head -1)
if [ -z "$GO_MAJOR" ] || [ "$GO_MAJOR" -lt 25 ]; then
	echo "installing Go 1.25 ..."
	curl -sL "https://go.dev/dl/go1.25.3.linux-amd64.tar.gz" | sudo tar -C /usr/local -xz
	export PATH="/usr/local/go/bin:$PATH"
fi
go version

echo " "
echo "=================================="
echo "kdae-panel: 交叉编译 aarch64 面板"
echo "=================================="
mkdir -p "$KDAE_BIN"
CGO_ENABLED=0 GOOS=linux GOARCH=arm64 go build -trimpath \
	-ldflags "-s -w -X main.version=$KDAE_VER" \
	-o "$KDAE_BIN/kdae-panel" ./cmd/kdae-panel
file "$KDAE_BIN/kdae-panel"

echo " "
echo "=================================="
echo "kdae-panel: 挂载本地 feed"
echo "=================================="
cd "$WRT_DIR"
echo "src-link kdae $KDAE_SRC/openwrt" >> feeds.conf.default
./scripts/feeds update kdae
./scripts/feeds install -a -p kdae

#导出给后续编译步骤（WRT-CORE.yml 的 Compile Firmware）
{
	echo "KDAE_PANEL_BIN=$KDAE_BIN/kdae-panel"
	echo "KDAE_PANEL_VERSION=$KDAE_VER"
} >> "$GITHUB_ENV"

echo "kdae-panel feed ready!"

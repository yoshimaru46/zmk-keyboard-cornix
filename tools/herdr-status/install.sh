#!/bin/sh
# herdr-status をビルドして LaunchAgent として常駐させる。更新時も同じコマンドを再実行する。
#   ./install.sh              ビルド・配置・(再)起動
#   ./install.sh --uninstall  停止して削除
set -eu
cd "$(dirname "$0")"

label=com.yoshimaru46.herdr-status
bin="$HOME/.local/bin/herdr-status"
plist="$HOME/Library/LaunchAgents/$label.plist"
log="$HOME/Library/Logs/herdr-status.log"
domain="gui/$(id -u)"

stop() {
    launchctl bootout "$domain/$label" 2>/dev/null || return 0
    # bootout は非同期で、消える前に bootstrap すると失敗する
    while launchctl print "$domain/$label" >/dev/null 2>&1; do sleep 0.2; done
}

if [ "${1:-}" = "--uninstall" ]; then
    stop
    rm -f "$bin" "$plist"
    exit 0
fi

swiftc -O -swift-version 5 -o herdr-status main.swift

mkdir -p "$(dirname "$bin")" "$(dirname "$plist")"
stop
cp herdr-status "$bin"
cat > "$plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$label</string>
    <key>ProgramArguments</key>
    <array>
        <string>$bin</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardErrorPath</key>
    <string>$log</string>
</dict>
</plist>
PLIST
launchctl bootstrap "$domain" "$plist"

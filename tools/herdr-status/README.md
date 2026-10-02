# herdr-status

herdr のエージェント状態を Cornix ドングルの画面へ Raw HID で送る Mac 側の常駐プログラム。
受信側は zmk-dongle-screen の agent ウィジェット（`config/dongle_screen.conf` の
`CONFIG_DONGLE_SCREEN_AGENT_ACTIVE=y`）。

## 導入・更新

```sh
tools/herdr-status/install.sh
```

ビルドして `~/.local/bin/herdr-status` に置き、LaunchAgent
（`~/Library/LaunchAgents/com.yoshimaru46.herdr-status.plist`）として起動する。
`main.swift` を変更したときも同じコマンドを再実行すれば差し替えて再起動される。
Xcode Command Line Tools（`swiftc`）が必要。

## 確認

```sh
tools/herdr-status/herdr-status --print            # 送信せず、送る内容を 1 回だけ表示
launchctl print gui/$(id -u)/com.yoshimaru46.herdr-status | grep state
tail ~/Library/Logs/herdr-status.log               # 送信エラー
```

herdr が `~/.local/bin`・Homebrew 以外にある場合は環境変数 `HERDR_BIN` で指定する
（LaunchAgent 経由で使うなら plist に `EnvironmentVariables` を足す）。

## 削除

```sh
tools/herdr-status/install.sh --uninstall
```

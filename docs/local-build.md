# ローカルビルド手順（macOS / Nix）

このリポジトリのファームウェアを手元の Mac でビルドする手順。
ビルド環境は Nix flake（`flake.nix`）で管理されている。

## 前提：Nix のインストール（初回のみ）

```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```

インストール後はターミナルを再起動する。新しいシェルで `nix` が PATH に
入っていない場合は次の行を読み込む（または `~/.zshrc` 等に追記）。

```bash
source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
nix --version   # 動作確認
```

## west ワークスペースの初期化（初回のみ）

ZMK 本体・Zephyr RTOS・各種モジュールを取得する。初回は数分〜十数分かかる。

```bash
cd ~/ghq/github.com/yoshimaru46/zmk-keyboard-cornix
nix develop --command just init
```

取得物（`zmk/`, `zephyr/`, `modules/`, `zmk-helpers/` など）は `.gitignore`
済みなのでコミット対象にはならない。

## ビルド

> **注意：`just build` は使わない。**
> このフォークの `Justfile` は「ZMK ライブラリを別ディレクトリに置く」前提で、
> 今の in-place な `just init` 構成と噛み合わない（存在しない `config2` を参照し、
> さらに `ZMK_EXTRA_MODULES=$(pwd)` が repo 直下の `zephyr/`(RTOS) を巻き込んで
> Kconfig 再帰エラーになる）。そのため `west build` を直接実行する。

### ドングル（Prospector = XIAO BLE + dongle_screen）

```bash
cd ~/ghq/github.com/yoshimaru46/zmk-keyboard-cornix
nix develop --command west build -s zmk/app -d .build/dongle -b "xiao_ble//zmk" \
  -S "studio-rpc-usb-uart nrf52840-nosd" -- \
  -DZMK_CONFIG="$(pwd)/config" \
  -DSHIELD="cornix_dongle_adapter dongle_screen" \
  -DBOARD_ROOT="$(pwd)"
```

成果物：`.build/dongle/zephyr/zmk.uf2`

```bash
mkdir -p firmware
cp .build/dongle/zephyr/zmk.uf2 firmware/cornix_dongle_prospector_nosd.uf2
```

### ポイント解説

| オプション | 意味 |
|---|---|
| `-s zmk/app` | ZMK アプリのソース（`just init` が repo 直下に取得） |
| `-b "xiao_ble//zmk"` | ボード（ドングルの XIAO BLE。ZMK 用は `//zmk` 付き） |
| `-S "..."` | snippet（USB UART での Studio + nosd） |
| `-DZMK_CONFIG=.../config` | キーマップ・`*.conf` のあるディレクトリ |
| `-DSHIELD="..."` | dongle adapter + 画面シールド |
| `-DBOARD_ROOT="$(pwd)"` | repo の `boards/` を board root に追加（`ZMK_EXTRA_MODULES` は使わない） |

`cornix.keymap` は Cornix キーボード名で自動探索されるため、`-DKEYMAP` 指定は不要。

## 他ターゲット

ビルド対象の一覧は `build.yaml` の `include` を参照。例：

| artifact | board | shield |
|---|---|---|
| `cornix_dongle_prospector_nosd` | `xiao_ble//zmk` | `cornix_dongle_adapter dongle_screen` |
| `cornix_dongle_nosd` | `nice_nano/nrf52840/zmk` | `cornix_dongle_adapter cornix_dongle_eyelash dongle_display` |
| `cornix_left_default_nosd` | `cornix_left` | （なし） |
| `cornix_right_nosd` | `cornix_right` | （なし） |

ボード単体（シールドなし）ターゲットは `-DSHIELD` を省略する。

## 書き込み

1. XIAO / nice!nano をブートローダーモードにする（リセットボタンを素早く2回押す）
2. マウントされたドライブに `.uf2` をコピー

## クリーン

```bash
rm -rf .build firmware      # ビルド成果物
nix develop --command just clean-all   # west ワークスペースごと削除（再 init が必要）
```

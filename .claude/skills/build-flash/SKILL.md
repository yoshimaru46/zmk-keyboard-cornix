---
name: build-flash
description: cornix ファームウェアを手元の Mac でビルドしてドングル/キーボードに書き込む。「ローカルでビルド」「ドングルに書き込み」「flash」「uf2 を作る」等で使う。詳細手順は docs/local-build.md。
---

# cornix ローカルビルド＆書き込み

Nix flake + west でビルドし、UF2 をブートローダーモードのデバイスにコピーする。

## 前提（初回のみ）

```bash
nix develop --command just init   # west ワークスペース取得（数分〜）
```

未導入なら Nix を入れる手順は `docs/local-build.md` 参照。`just build` は使わない（後述）。

## ビルド（`west build` を直接実行）

デフォルトは Prospector ドングル。リポジトリ直下で実行する。

```bash
nix develop --command west build -s zmk/app -d .build/dongle -b "xiao_ble//zmk" \
  -S "studio-rpc-usb-uart nrf52840-nosd" -- \
  -DZMK_CONFIG="$(pwd)/config" \
  -DSHIELD="cornix_dongle_adapter dongle_screen" \
  -DBOARD_ROOT="$(pwd)"
```

成果物：`.build/dongle/zephyr/zmk.uf2`

### 他ターゲット（`-d` と `-b/-S/-DSHIELD` を差し替え）

| artifact | board (`-b`) | shield (`-DSHIELD`) | snippet (`-S`) |
|---|---|---|---|
| dongle_prospector | `xiao_ble//zmk` | `cornix_dongle_adapter dongle_screen` | `studio-rpc-usb-uart nrf52840-nosd` |
| dongle (nice!nano) | `nice_nano/nrf52840/zmk` | `cornix_dongle_adapter cornix_dongle_eyelash dongle_display` | `studio-rpc-usb-uart nrf52840-nosd` |
| left | `cornix_left` | （なし＝`-DSHIELD` 省略） | （省略） |
| right | `cornix_right` | （なし＝`-DSHIELD` 省略） | （省略） |

`cornix.keymap` は自動探索されるため `-DKEYMAP` 不要。全一覧は `build.yaml`。

## 書き込み

1. デバイスをブートローダーモードにする（リセットを素早く2回押す）
2. マウントされたドライブに UF2 をコピー

```bash
cp .build/dongle/zephyr/zmk.uf2 /Volumes/XIAO-SENSE/   # nice!nano は /Volumes/NICENANO/
```

`ls /Volumes/` でドライブ名を確認してからコピーする。

## 注意

- `just build` は使わない（このフォークの Justfile は in-place 構成と噛み合わずビルドが壊れる）。`west build` を直接叩く。
- ビルド成果物（`.build/`, `firmware/`）は `.gitignore` 済み。
- クリーン：`rm -rf .build firmware`（再 init は `just clean-all`）。

# CLAUDE.md

## ファームウェアのビルドは必ずローカルで行う

キーマップや設定を変更したら、GitHub Actions を待たずに**ローカルでビルドして確認する**。

手順は `build-flash` skill（`.claude/skills/build-flash/SKILL.md`）に従う。詳細・背景は
`docs/local-build.md`。要点だけ再掲:

- `nix develop --command west build ...` を直接叩く。**`just build` は使わない**
  （`config2` 参照と `ZMK_EXTRA_MODULES` による Kconfig 再帰エラーで壊れる）
- west の依存（`zmk/`, `zephyr/`, `modules/` 等）は取得済みなので `just init` は不要
- ドングル構成ではキーマップは central（ドングル）側にあるため、キーマップ変更時はドングルのみ書き込めばよい

## リポジトリ運用

- PR は `gh pr create --repo yoshimaru46/zmk-keyboard-cornix` と明示し、フォーク元へ誤送しない

## 実機は 2 台運用

- 1 台はドングル経由（左 `cornix_ph_left` + 右 `cornix_right` + ドングル）、もう 1 台は Bluetooth 直結（左 `cornix_left` + 右 `cornix_right`）
- 書き込み前に、対象がどちらの台・どちら側かを必ず確認する（ブートローダーのドライブ名は左右・台とも同じ `cornix` で判別できない）

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

# CLAUDE.md

## ファームウェアのビルドは GitHub Actions で行う

キーマップや設定を変更したら、push して **Actions でビルドして確認する**。
手元に toolchain と west の依存（約 9GiB）を置かないため、ローカルではビルドしない
（`west init` / `west update` や Nix・Zephyr SDK の導入もしない）。

手順は `build-flash` skill（`.claude/skills/build-flash/SKILL.md`）に従う。

- 依存は `config/west.yml`、再利用 workflow は `.github/workflows/` で SHA 固定。上げるときは独立した PR にする
  - ZMK を上げるときは workflow の SHA と、west.yml の zephyr の SHA・blocklist も揃える
- ドングル構成ではキーマップは central（ドングル）側にあるため、キーマップ変更時はドングルのみ書き込めばよい

## リポジトリ運用

- PR は `gh pr create --repo yoshimaru46/zmk-keyboard-cornix` と明示し、フォーク元へ誤送しない

## 実機は 2 台運用

- 1 台はドングル経由（左 `cornix_ph_left` + 右 `cornix_right` + ドングル）、もう 1 台は Bluetooth 直結（左 `cornix_left` + 右 `cornix_right`）
- 書き込み前に、対象がどちらの台・どちら側かを必ず確認する（ブートローダーのドライブ名は左右・台とも同じ `cornix` で判別できない）

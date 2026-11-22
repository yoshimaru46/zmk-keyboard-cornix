---
name: build-flash
description: cornix ファームウェアを GitHub Actions でビルドし、UF2 を取得してドングル/キーボードに書き込む。「ビルド」「ドングルに書き込み」「flash」「uf2 を作る」等で使う。
---

# cornix ビルド＆書き込み

GitHub Actions でビルドし、取得した UF2 をブートローダーモードのデバイスにコピーする。
手元ではビルドしない。

## ビルド

ビルドされるのは push 済みのコミットだけ。未 push の変更は先に push する。

```bash
# 最終行に run の URL が出る。末尾の数字が run ID
gh workflow run build.yml --repo yoshimaru46/zmk-keyboard-cornix --ref <ブランチ>

# 全ターゲットで 5 分前後
gh run watch <run ID> --repo yoshimaru46/zmk-keyboard-cornix --exit-status --interval 30 > /dev/null

# 書き込む前に、headSha が意図したコミットか確かめる
gh run view <run ID> --repo yoshimaru46/zmk-keyboard-cornix --json headSha,conclusion
```

## 取得

```bash
gh run download <run ID> --repo yoshimaru46/zmk-keyboard-cornix --name firmware --dir "firmware/<run ID>"
```

成果物の保持は 90 日。一覧は `build.yaml` の `artifact-name`。

| 書き込み先 | UF2 |
|---|---|
| ドングル（Prospector） | `cornix_dongle_prospector_nosd.uf2` |
| ドングル（nice!nano） | `cornix_dongle_nosd.uf2` |
| 左（ドングル経由の台） | `cornix_left_for_dongle_nosd.uf2` |
| 左（Bluetooth 直結の台） | `cornix_left_default_nosd.uf2` |
| 右（両台共通） | `cornix_right_nosd.uf2` |

## 確認

`.config` と生成された devicetree は、各ジョブのログに全文が出る。

```bash
gh run view <run ID> --repo yoshimaru46/zmk-keyboard-cornix --json jobs --jq '.jobs[] | [.databaseId, .name] | @tsv'
gh run view --repo yoshimaru46/zmk-keyboard-cornix --job <job ID> --log
```

## 書き込み

1. デバイスをブートローダーモードにする（リセットを素早く2回押す）
2. `ls /Volumes/` でドライブ名を確認し、UF2 をコピーする

```bash
cp "firmware/<run ID>/cornix_dongle_prospector_nosd.uf2" /Volumes/XIAO-SENSE/   # nice!nano は /Volumes/NICENANO/
```

`firmware/` は `.gitignore` 済み。書き込みが済んだら消してよい。

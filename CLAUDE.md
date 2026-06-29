# CLAUDE.md

このリポジトリは SeaSideX（Keyball44 右手トラックボール版）の ZMK ファームウェア設定。

## ローカルビルド

Docker でファームウェアをビルドする。GitHub Actions の `build-user-config.yml` と同等の構成をローカルで再現している。

```bash
./build.sh
```

### 前提

- Docker が利用できること（ビルドイメージ `zmkfirmware/zmk-build-arm:3.5` を使用）。
- 初回は `west update` で ZMK 本体・Zephyr・各モジュールを clone するため時間がかかる。

### 挙動

- `build.yaml` の `include` から `(board, shield, snippet)` を読み取り、各ターゲットをビルドする。
- 各ビルドは Docker コンテナ内で `config/` を `/tmp/zmk-config/config` にコピーし、`west init -l` → `west update` → `west zephyr-export` → `west build` を実行する。
- 元リポジトリの Zephyr モジュール（`zephyr/module.yml`）は `-DZMK_EXTRA_MODULES=/workspace` で参照する。
- 生成された `zmk.uf2` を `dist/<artifact-name>.uf2` にコピーする。`<artifact-name>` は `shield`（空白は `-` に置換）+ `board`。

### ビルドターゲット（`build.yaml`）

| board | shield | snippet | 出力 |
| --- | --- | --- | --- |
| `seeeduino_xiao_ble` | `SeaSide44_R rgbled_adapter` | `studio-rpc-usb-uart` | `SeaSide44_R-rgbled_adapter-seeeduino_xiao_ble.uf2`（右手・トラックボール側） |
| `seeeduino_xiao_ble` | `SeaSide44_L rgbled_adapter` | - | `SeaSide44_L-rgbled_adapter-seeeduino_xiao_ble.uf2`（左手側） |
| `seeeduino_xiao_ble` | `settings_reset` | - | `settings_reset-seeeduino_xiao_ble.uf2`（設定リセット用） |

ビルドターゲットを変更する場合は `build.yaml` の `include` を編集する。

### 出力

- `dist/*.uf2` に出力される。`dist/` は `.gitignore` で除外されている。

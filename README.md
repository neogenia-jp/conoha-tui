# conoha-tui

GMO ConoHa VPS をターミナル上で管理する TUI（Terminal User Interface）アプリケーションです。

---

## 概要

ConoHa API（v2 / v3）を通じて VPS の一覧表示・電源操作・ポート管理、内部ネットワーク、追加ディスク、オブジェクトストレージの情報を確認できます。複数アカウント・複数リージョンに対応しており、設定はローカルの SQLite データベースに保存されます。

---

## 動作要件

| 項目 | バージョン |
|------|-----------|
| Ruby | >= 3.4.4  |
| OS   | macOS / Linux |

---

## インストール・起動

```sh
git clone <このリポジトリ>
cd conoha-tui
bundle install
bin/conoha-tui
```

本番環境では開発用 gem（`development`, `test`）を除外してインストールしてください。

```sh
bundle config set without 'development test'
bundle install --deployment
```

---

## 初回設定

初回起動時は自動的に **設定画面** が表示されます。

1. `a` キーでアカウント追加フォームを開く
2. 各フィールドを入力する（`Tab` で次の項目へ移動、`Cmd+V` でペースト可）

| フィールド | 説明 |
|-----------|------|
| 表示名 | アプリ内で識別するための任意の名前 |
| VPS バージョン | `←` / `→` で選択（`2` / `3`）。入力項目とリージョンの選択肢が切り替わる |
| テナントID | ConoHa コントロールパネル → API 情報の「テナントID」 |
| ユーザー名 | （VPS v2 のみ）API ユーザー名（例: `gncu12345678`） |
| ユーザーID | （VPS v3 のみ）API ユーザーの「ユーザーID」 |
| パスワード | API ユーザーのパスワード |
| リージョン | `←` / `→` で選択（v2: `tyo1` / `tyo2` / `tyo3` / `sin1` / `sjc1`、v3: `c3j1`） |

3. `Enter` で保存する
4. **`Alt+1` を押して VPS 一覧タブへ移動する**

---

## 画面一覧と操作方法

### タブ切替（全画面共通）

| キー | 操作 |
|------|------|
| `Alt+1` | VPS 一覧 |
| `Alt+2` | 内部ネットワーク |
| `Alt+3` | 追加ディスク |
| `Alt+4` | オブジェクトストレージ |
| `Alt+5` | 設定 |
| `Alt+→` | 次のタブへ |
| `Alt+←` | 前のタブへ |
| `q` / `Ctrl+C` | 終了 |

---

## リモートデバッグ（rdbg）

`debug` gem を利用して VS Code からリモートアタッチできます。

```sh
bin/conoha-tui --rdebug
```

オプション:

| オプション | 説明 |
|-----------|------|
| `--rdebug` | リモートデバッグを有効化（attach まで待機） |
| `--rdebug-host HOST` | bind ホスト（省略時 `127.0.0.1`） |
| `--rdebug-port PORT` | bind ポート（省略時は rdbg のデフォルト） |

例:

```sh
bin/conoha-tui --rdebug --rdebug-host 127.0.0.1 --rdebug-port 12345
```

`debug` gem は `development,test` グループに入っているため、本番で `development,test` を除外していれば `--rdebug` は有効化できません。

---

### 1. VPS 一覧（タブ `1`）

全アカウント・全リージョンの VPS をテーブル形式で表示します。

| キー | 操作 |
|------|------|
| `↑` / `↓`（または `k` / `j`） | 行を選択 |
| `Enter` | 選択した VPS の詳細画面へ |
| `r` | VPS 情報を API から再取得 |
| `s` | ソート項目を切替（名前 → 作成日 → 契約期限） |
| `S` | 昇順 / 降順の切替 |
| `/` | 名前・ホストでフィルタ入力モード |
| `Esc` | フィルタ解除 |

---

### 2. VPS 詳細（VPS 一覧で `Enter`）

選択した VPS の詳細情報・電源操作・ポート管理を行います。

| キー | 操作 |
|------|------|
| `Tab` | フォーカス切替（情報欄 ↔ ポート一覧） |
| `s` | 電源 ON / OFF |
| `r` | 情報を再取得 |
| `↑` / `↓`（または `k` / `j`） | ポート一覧の選択（ポートフォーカス時） |
| `o` | ポートを開放（ポートフォーカス時） |
| `d` / `Delete` | ポートをクローズ（ポートフォーカス時） |
| `Esc` / `Backspace` | VPS 一覧に戻る |

---

### 3. 内部ネットワーク（タブ `2`）

ネットワークと接続 VPS をツリー形式で表示します。

| キー | 操作 |
|------|------|
| `↑` / `↓`（または `k` / `j`） | 移動 |
| `Enter` / `Space` | ツリーの展開 / 折畳 |
| `r` | 再取得 |

---

### 4. 追加ディスク（タブ `3`）

追加ディスクと接続 VPS をツリー形式で表示します。

| キー | 操作 |
|------|------|
| `↑` / `↓`（または `k` / `j`） | 移動 |
| `Enter` / `Space` | ツリーの展開 / 折畳 |
| `r` | 再取得 |

---

### 5. オブジェクトストレージ（タブ `4`）

コンテナ一覧を表示します。

| キー | 操作 |
|------|------|
| `↑` / `↓`（または `k` / `j`） | 移動 |
| `r` | 再取得 |

---

### 6. 設定（タブ `5`）

ConoHa API アカウントの追加・編集・削除を行います。

| キー | 操作 |
|------|------|
| `a` | アカウントを追加 |
| `e` | 選択中のアカウントを編集 |
| `d` | 選択中のアカウントを削除 |
| `↑` / `↓` | アカウントを選択 |

**フォーム入力中:**

| キー | 操作 |
|------|------|
| `Tab` | 次の入力項目へ |
| `Backspace` | 1文字削除 |
| `Cmd+V` | クリップボードからペースト |
| `←` / `→` | リージョン / バージョンの切替 |
| `Enter` | 保存 |
| `Esc` | キャンセル |

---

## ディレクトリ構成

```
conoha-tui/
├── bin/
│   └── conoha-tui          # 実行エントリポイント
├── lib/
│   └── conoha_tui/
│       ├── api/            # ConoHa API クライアント
│       │   ├── auth_v2.rb      # Identity API v2 認証
│       │   ├── auth_v3.rb      # Identity API v3 認証
│       │   ├── compute_client.rb    # Nova (VPS) API
│       │   ├── network_client.rb    # Neutron (ネットワーク) API
│       │   ├── volume_client.rb     # Cinder (ディスク) API
│       │   └── object_storage_client.rb  # Swift API
│       ├── config/
│       │   └── settings.rb     # アカウント設定管理
│       ├── db/
│       │   ├── database.rb     # SQLite 接続管理
│       │   ├── schema.rb       # スキーマ定義・マイグレーション
│       │   └── repositories/   # データ永続化 (VPS / ネットワーク / ディスク / ...)
│       ├── models/             # ドメインモデル (Vps / Network / Disk / ...)
│       ├── services/           # ビジネスロジック (VpsService 等)
│       └── ui/
│           ├── app.rb          # メインループ・タブ管理・画面遷移
│           ├── components/     # HelpBar / StatusBar 等の共通 UI 部品
│           └── screens/        # 各タブ画面
│               ├── base_screen.rb
│               ├── vps_list_screen.rb
│               ├── vps_detail_screen.rb
│               ├── network_list_screen.rb
│               ├── disk_list_screen.rb
│               ├── object_storage_screen.rb
│               └── settings_screen.rb
└── test/                   # minitest テストスイート
```

---

## テスト実行

```sh
bundle exec rake test
```

---

## 技術スタック

| ライブラリ | 用途 |
|-----------|------|
| [ratatui_ruby](https://www.ratatui-ruby.dev/) ~> 1.5 | Rust 製 TUI レンダリングエンジンの Ruby バインディング |
| [faraday](https://lostisland.github.io/faraday/) ~> 2.0 | HTTP クライアント（ConoHa API 通信） |
| [sqlite3](https://github.com/sparklemotion/sqlite3-ruby) ~> 2.3 | ローカルキャッシュ DB |
| [minitest](https://github.com/minitest/minitest) ~> 5.25 | テストフレームワーク |
| [webmock](https://github.com/bblimke/webmock) | HTTP スタブ（テスト用） |

---

## データ保存先

設定ファイルおよびキャッシュ DB は `~/.config/conoha-tui/` 以下に保存されます。

```
~/.config/conoha-tui/
├── config.json   # アカウント設定 (JSON)
└── conoha.db     # VPS・ネットワーク等のキャッシュ (SQLite)
```

別のマシンへ移す場合は `config.json` をコピーしてください（`conoha.db` はキャッシュなので `r` キーで再取得できます）。
公式 ConoHa CLI の `~/.conoha/config` とは別物で、このアプリは読み書きしません。

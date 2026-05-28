# conoha-tui 向け Copilot 指示

このリポジトリは、ConoHa VPS を管理する Ruby 製 TUI アプリケーションです。

## 前提条件

- 回答は必ず日本語でしてください
- 大規模な変更（200行以上）を行う前には、まず変更計画を提案してください
- コード改修時はできるだけ既存コードの書き方に倣って下さい。
- ただし、改修により複雑度が上がってしまって、コードの可読性や保守性が下がってしまうようであれば、より良い構造を検討し、提案して下さい。
- 改修に際しては、一般的な可読性や保守性のレベルを維持できるか確認し、そうでない場合は、必ずより良い構造にリファクタリングすることを心がけて下さい。
- 特にTODOコメントが書いてある場合は、技術的負債であることが多いので、まずリファクタリングできないか検討して下さい。
- コード改修完了後の説明は不要です。コードを読めば分かるので。「改修完了です」の一言でOKです。

## プロジェクト基本情報
- 言語: Ruby（対象バージョン: 3.4.4）
- UI: `ratatui_ruby`
- HTTP: `faraday`
- ストレージ: `sqlite3`
- テスト: `minitest`, `webmock`, `mocha`
- エントリーポイント: `bin/conoha-tui`

## アーキテクチャ
- メイン UI ループとタブ遷移: `lib/conoha_tui/ui/app.rb`
- 画面: `lib/conoha_tui/ui/screens/*`
- サービス層: `lib/conoha_tui/services/*`
- API クライアント: `lib/conoha_tui/api/*`
- データモデル: `lib/conoha_tui/models/*`
- SQLite リポジトリ: `lib/conoha_tui/db/repositories/*`

## コーディング規約
- 変更は最小限かつ局所的に行う。
- `ConohaTui` 配下の既存命名とモジュール構造を維持する。
- 既存ファイルが非 ASCII を使っていない限り、コード/コメントは ASCII 優先とする。
- 無関係な領域のリファクタはしない。

## UI とイベント処理の規約
- 画面の描画シグネチャは `render(frame, area = frame.area)` を使う。
- 画面レイアウトは `build_layout(area)` で組み立てる（`frame.with_area` は使わない）。
- Ratatui のイベントはパターンマッチ可能なオブジェクト。
  - `in type: :key, code: ...` のようなパターンマッチと束縛変数を優先する。
  - イベントをハッシュとして扱わない（`event[:code]` は使わない）。
- タブ切替は `Alt+1..5` と `Alt+Left/Alt+Right` を使う。

## ConoHa / 認証メモ
- Identity エンドポイントは v2 Keystone ホスト `https://identity.<region>.conoha.io` を使用する。
- VPS version 3 アカウントでも、現状の認証処理は `AuthV2` を経由する。
- tenant が未設定の場合は、CLI 設定のフォールバックや tenant 一覧取得による解決が必要な場合がある。

## データ表示の期待値
- VPS 一覧の名前列は、利用可能ならネームタグ相当の値を優先表示する。
- VPS 一覧の `Ver` 列は左端に配置する。
- CPU/RAM が一覧レスポンスに無い場合は、flavor 参照による補完が必要な場合がある。
- 契約期限は API 側データ次第で欠落することがある。

## 詳細画面 UX の期待値
- `Esc` で一覧画面に戻ること。
- 電源操作（`s`）は実行前に確認ダイアログを表示すること。
- ポート開放（`o`）は枠付きの中央モーダルダイアログで入力すること。

## テストと検証
- テスト実行: `bundle exec rake test`
- UI 変更時は `bin/conoha-tui` を起動して手動確認する。
- API/認証コード変更時は `test/api` と `test/services` の WebMock テストを更新する。

## ドキュメント
- `README.md` のキー操作・画面挙動を実装と一致させる。

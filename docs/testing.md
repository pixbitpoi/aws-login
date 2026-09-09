# テスト

```bash
bash tests/run.sh          # すべて実行
bash tests/run.sh mfa      # 名前に mfa を含むテストだけ実行
```

`tests/bin/aws` を模擬 AWS CLI として使います。実際の AWS API や `~/.aws` は変更しません。
プロファイル設定・ログイン状態は作業用のテンポラリディレクトリ内だけで完結し、
テストは 1 件ずつ独立したプロセスで実行します。

| ファイル | 検証する内容 |
| --- | --- |
| `tests/cases/arguments_test.sh` | オプションの解析、ヘルプ、AWS CLI 不在 |
| `tests/cases/mode_test.sh` | プロファイル名の決定、MFA / SSO の判定、`-sso` 接尾辞 |
| `tests/cases/mfa_test.sh` | 保存先の検査、再利用と再ログイン、デバイス・期間の指定、有効期限の保存と表示 |
| `tests/cases/sso_test.sh` | セッションの再利用とログイン、ブラウザ関連オプション、有効期限の表示 |
| `tests/cases/session_test.sh` | STS による確認、期限切れと通信・権限エラーの切り分け、リージョン解決 |
| `tests/cases/command_test.sh` | 後続コマンドへの環境変数・引数・終了コードの引き継ぎ |
| `tests/cases/interactive_test.sh` | 擬似端末上での対話セットアップ、プロファイル・認証方式メニューのキー操作 |
| `tests/cases/lint_test.sh` | 構文チェック、実行権限、shellcheck（あれば） |

## テストの追加

`tests/cases/*_test.sh` に `test_` で始まる関数を書くだけです。
共通の前提条件（`given_...`）とアサーション（`assert_...`）は `tests/lib/helpers.sh` にあります。

## 補足

- 擬似端末が使えない環境では対話テストをスキップします。
- 実際のブラウザ認証や AWS CLI 本体の対話ウィザードはテストの対象外です。

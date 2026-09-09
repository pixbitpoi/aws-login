# AGENTS.md

AI エージェント向けのプロジェクト案内。人間向けの説明は README.md にある。

## このプロジェクト

`bin/aws-login` は AWS CLI のログイン（IAM ユーザー + MFA、IAM Identity Center の SSO）をまとめて扱う
Bash のラッパー。認証方式の判定、未設定時の対話セットアップ、認証の再利用・更新、後続コマンドの実行を行う。

| パス | 役割 |
| --- | --- |
| `bin/aws-login` | 本体。開発中も `./bin/aws-login` で叩ける。処理の流れは末尾の `main()` を読む |
| `README.md` | 利用者向け。使い方とユースケース、トラブルシューティング |
| `docs/internals.md` | 内部仕様。名前の決定規則、保存先、標準コマンドとの対応、制約 |
| `docs/testing.md` | テストの実行方法とケース一覧 |
| `docs/release.md` | Homebrew での配布。配布物の範囲とタグ打ちの手順 |
| `tests/run.sh` | テストランナー |
| `tests/bin/aws` | 模擬 AWS CLI。テスト中は本物の代わりにこれが呼ばれる |
| `tests/lib/helpers.sh` | テスト共通の前提条件（`given_*`）とアサーション（`assert_*`） |
| `tests/cases/*_test.sh` | テスト本体。`test_` で始まる関数が 1 件 |

## 作業の前提

- 言語はすべて日本語。コメント、メッセージ、ドキュメント、テスト名の説明も日本語で書く。
- 依存は Bash と AWS CLI v2 だけ。jq、python、fzf、tput などを本体から呼ばない。
  GNU と BSD（macOS 標準）の両方で動くコマンドの使い方をする。`date` は両対応の分岐がすでにある。
- スクリプトは `set -euo pipefail`。経過表示は `ui_*`（標準エラー）、異常終了は `fail`。
  標準出力は後続コマンドのために空けておき、本体からは使い方の案内以外を出さない。
  記号と色の規則は `docs/internals.md`「表示の規則」が正本。独自の記号や `printf` を各所に足さない。
- AWS の設定は必ず AWS CLI 経由（`aws configure get/set/list-profiles`）で読み書きする。
  `~/.aws` のファイルを直接読まない。テストの模擬 CLI が置き換えられなくなる。
- 親シェルの環境は変えない。`source` される前提のコードを書かない。
- AWS 側の操作（ユーザー作成、MFA 登録、SSO の権限割り当て）は自動化しない。案内だけにする。
- 共通ルールはこのファイルが正本。`CLAUDE.md` は `@AGENTS.md` を読み込むだけの薄い入口で、ここの内容を複製しない。

## 変更するとき

1. 動作を変えたら `tests/cases/` に対応するテストを足す。対話部分は `interactive_test.sh`（擬似端末）。
2. `bash tests/run.sh` を実行して全件成功を確認する。`bash tests/run.sh mfa` のように絞り込める。
3. 利用者に見える動作が変わったら README.md を、内部規則が変わったら `docs/internals.md` を更新する。
   README は「すぐ使う → ユースケース別 → オプション → トラブルシューティング」の順を保ち、
   内部の細かい規則は README に書かず `docs/internals.md` に置く。
4. `shellcheck` があれば `lint_test.sh` が実行する。なくてもテストはスキップ扱いで通る。

## 模擬 AWS CLI の扱い

- 本体が新しい `aws` サブコマンドを呼ぶようになったら、`tests/bin/aws` に同じサブコマンドの分岐を足す。
  未対応の呼び出しは終了コード 91 で失敗する。
- 状態は `$AWS_MOCK_DIR` 配下（`profiles/`、`sessions/`、`log`）だけで持つ。
- 期限や失敗の再現は `AWS_MOCK_STS_ERROR`、`AWS_MOCK_LOGIN_EXIT`、`AWS_MOCK_EXPIRATION` などの環境変数で行う。
  一覧は `tests/bin/aws` の先頭コメントにある。

## 設計上の決まり

- MFA は元プロファイル `<名前>` と一時認証情報の保存先 `<名前>-mfa` を分ける。SSO は `<名前>-sso` を直接使う。
- `--profile` 未指定で端末があれば、`default` が設定済みでも必ず選択メニューを出す。黙って `default` を使わない。
- 期限切れの判定は STS の結果だけで行う。ローカルに保存した期限は表示用で、判定には使わない。
- MFA の期限は AWS CLI が保存しないため、`mfa-login` の出力から読み取って `aws_credential_expiration` に控える。
  この項目は AWS CLI 自身は参照しない。

## コミット

- メッセージは日本語。件名は Conventional Commits（`feat:`、`fix:`、`docs:`、`test:`、`refactor:`、`chore:`）で簡潔に。
- 本文は箇条書きで 3 つ程度。何を変えたかを 1 行ずつ書き、理由が自明でなければ添える。
- 1 コミットに 1 つの目的。ドキュメントだけの変更は `docs:` に分ける。

```
feat: プロファイルの選択メニューを追加

- 引数なしの実行で設定済みプロファイルを一覧表示し、矢印キーと番号で選べるようにした
- -mfa で終わる一時認証情報の保存先は一覧から隠す
- 一覧が空の場合は従来どおり名前を入力する
```

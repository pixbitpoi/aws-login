# AWS ログインスクリプト

`aws-login` は AWS CLI のログインをまとめて面倒見るラッパーです。

- MFA / SSO のどちらを使うかを設定から判定します
- 未設定なら対話でセットアップを案内します
- 有効な認証情報があれば再利用し、期限切れならログインし直します
- 認証後にそのまま後続コマンドを実行できます

必要なもの: Bash、AWS CLI v2（MFA は `aws configure mfa-login` 対応版）。jq は不要です。

## インストール

### Homebrew

```bash
brew tap pixbitpoi/tap
brew trust pixbitpoi/tap
brew install aws-login
```

`aws-login` コマンドとしてインストールされます。更新は `brew upgrade aws-login` です。
`brew trust` は Homebrew 6 以降で非公式 tap を読み込むために必要です。
AWS CLI v2 は依存に含めていないので、別途インストールしてください。
formula は [pixbitpoi/homebrew-tap](https://github.com/pixbitpoi/homebrew-tap) にあります。

### Homebrew を使わない場合

単一ファイルなので、PATH の通ったディレクトリへ置くだけです。

```bash
curl -fsSL https://raw.githubusercontent.com/pixbitpoi/aws-login/main/bin/aws-login \
  -o ~/.local/bin/aws-login && chmod +x ~/.local/bin/aws-login
```

PATH に `~/.local/bin` がなければ、シェルの設定ファイルに
`export PATH="$HOME/.local/bin:$PATH"` を追加してください。更新は同じコマンドを実行し直します。
Homebrew に切り替えるときは `~/.local/bin/aws-login` を削除して、どちらが実行されるか迷わないようにしてください。

## すぐ使う

```bash
# 引数なし。設定済みプロファイルの一覧から矢印キーか番号で選ぶ。未設定なら方式を聞いてセットアップ
aws-login

# プロファイルを指定してログイン（設定から MFA / SSO を自動判定）
aws-login --profile dev

# ログインしてから後続コマンドを実行
aws-login --profile dev -- aws s3 ls

# キャッシュを使わず再ログイン
aws-login --profile dev --refresh
```

MFA コードの入力やブラウザでの SSO 認証は、AWS CLI の通常のプロンプトで行います。
ログインが成功すると、接続に使うプロファイル・アカウント・ARN・有効期限を標準エラーに表示します。

```
◆ aws-login
  ✔ 認証情報を再利用  dev-mfa
    接続プロファイル  dev-mfa (mfa)
    アカウント        123456789012
    ARN               arn:aws:iam::123456789012:user/me
    有効期限          2026-09-07 03:04 JST  残り 11 時間 58 分
```

済んだことは ✔、これから行うことは ●、失敗は ✗ で示します。
色は端末に出力するときだけ付け、`NO_COLOR` を設定すると消えます。

## ユースケース別の使い方

### IAM ユーザー + MFA

**準備するもの**

- IAM ユーザーの長期アクセスキー
- そのユーザーに登録済みの OTP 型 MFA デバイスの ARN

AWS 側のユーザー作成・キー発行・MFA 登録は事前に済ませてください。

**実行**

```bash
# 初回。アクセスキーと MFA デバイスを対話で設定してからログイン
aws-login mfa --profile dev

# 2 回目以降。設定から MFA と判定される
aws-login --profile dev

# 認証後に後続コマンドを実行
aws-login --profile dev -- aws s3 ls
```

**結果**

- `dev` に長期キーと `mfa_serial` が保存されます
- 一時認証情報は `dev-mfa` に保存され、後続コマンドはこちらで実行されます
- `--profile` には常に元の `dev` を指定します（`dev-mfa` ではありません）

### IAM Identity Center (SSO)

**準備するもの**

- 組織の AWS アクセスポータルの開始 URL（例: `https://d-xxxxxxxxxx.awsapps.com/start`）
- IAM Identity Center を設定しているリージョン

どちらも管理者か招待メールで確認します。IAM ユーザーのアクセスキーや MFA は不要です。

**実行**

```bash
# 初回。SSO セッション・アカウント・ロールを対話で設定してからログイン
aws-login sso --profile dev

# 2 回目以降
aws-login --profile dev-sso

# 認証後に後続コマンドを実行
aws-login --profile dev-sso -- aws s3 ls

# ブラウザのない環境（デバイスコード方式）
aws-login sso --profile dev --use-device-code --no-browser
```

**結果**

- `sso` を明示すると、名前に `-sso` が付いた `dev-sso` を設定・使用します
- 認証キャッシュは AWS CLI が管理し、MFA のような別プロファイルは作りません
- すでに接尾辞なしで SSO 設定済みのプロファイルは、方式を省略すればそのまま使えます

### SSH / Session Manager と組み合わせる

```bash
aws-login mfa --profile myproj -- ssh myproj-bastion-stg
aws-login sso --profile myproj -- ssh myproj-bastion-stg
```

後続コマンドには `AWS_PROFILE` とリージョンが渡ります。
SSH の ProxyCommand 側で `--profile myproj-mfa` などを固定していると、そちらが優先されます。
方式を切り替えるなら ProxyCommand の固定指定を外すか、
MFA の場合は `--output-profile myproj-mfa` で保存先を SSH 側に合わせてください。
実際に使われる ProxyCommand は `ssh -G myproj-bastion-stg` で確認できます。

### 非対話環境で使う

`--profile NAME` を明示し、必要な設定を事前に済ませておいてください。
未指定の場合は `default` に認証設定があればそれを使い、なければ案内を表示して終了します。MFA コードや SSO の認証操作は省略できません。

## オプションと環境変数

引数が環境変数より優先されます。`aws-login --help` でも確認できます。

| 指定 | 用途・既定値 |
| --- | --- |
| `mfa` / `sso`（先頭） | 方式を明示。省略時は設定から判定 |
| `--profile NAME` | `AWS_PROFILE` → `AWS_SSO_PROFILE` → 一覧から選択（一覧が空なら入力、空 Enter で `default`） |
| `--region REGION` | `AWS_REGION` → `AWS_DEFAULT_REGION` → 元プロファイルの region |
| `--output-profile NAME` | MFA 専用。`AWS_MFA_PROFILE` → `<元>-mfa` |
| `--mfa-serial SERIAL` | MFA 専用。`AWS_MFA_SERIAL` → 元プロファイルの mfa_serial → 対話入力 |
| `--duration-seconds N` | MFA 専用。有効期間を AWS CLI に渡す |
| `--use-device-code` / `--no-browser` | SSO 専用。設定とログインに渡す |
| `--refresh` | 認証再利用を省略してログイン |
| `-- コマンド 引数...` | 認証後にコマンドを実行 |

## トラブルシューティング

**プロファイルの一覧が出て選択を求められる**
`--profile` も `AWS_PROFILE` も未指定なら毎回聞きます。↑↓ か `j` / `k`、番号でカーソルを動かし、Enter で決定します。
認証方式の質問も同じメニューで、`s`（SSO）と `m`（MFA）で直接選べます。
`default` があればそこにカーソルが乗っているので、Enter だけで進めます。`q` で中断します。
一覧にない名前を使うには末尾の「新しい名前を入力」を選びます。設定済みプロファイルがなければ、最初から名前の入力になります。
聞かれたくない場合は `--profile` を付けるか、`AWS_PROFILE` を設定してください。
非対話実行では聞かずに、`default` に認証設定があればそれを使います。

**一覧に `dev-mfa` が出てこない**
`-mfa` で終わる名前は MFA の一時認証情報の保存先なので隠しています。元の `dev` を選んでください。

**`--profile myproj` で SSO 設定が見つからない**
`myproj-sso` だけが設定済みでも `myproj` からは自動探索しません。
`sso --profile myproj` か `--profile myproj-sso` を使ってください。

**MFA の保存先で停止する**
保存先が元プロファイルと同じ、または長期キーや SSO 設定を持つ場合は拒否します。
`--output-profile` で別名を指定してください。

**SSO の設定が壊れている**
`aws configure sso --profile NAME` で修復してください。

**有効期限が表示されない**
MFA の期限は、このスクリプトでログインしたときに保存した控えから表示します。
標準コマンドで直接ログインした場合や、期限の行を読み取れなかった場合は表示を省略します。
`--refresh` で再ログインすれば保存されます。

**認証は通るのに SSM 接続が 403 になる**
`sts get-caller-identity` の成功は認証の有効性のみを示します。
接続プロファイル・アカウント・リージョンが合っていれば、SSM の権限や接続先の設定を確認してください。

**AssumeRole や credential_process のプロファイルを使いたい**
対象外です。検出はしますが、このスクリプトではログインできません。

## 詳細ドキュメント

- [内部仕様](docs/internals.md): プロファイル名の決定規則、保存先ファイル、標準コマンドとの対応、スクリプトの制約
- [テスト](docs/testing.md): テストの実行方法とケース一覧

```bash
bash tests/run.sh
```

参考: [AWS CLI mfa-login](https://docs.aws.amazon.com/cli/latest/reference/configure/mfa-login.html)、
[SSO 設定](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-sso.html)

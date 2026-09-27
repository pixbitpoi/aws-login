# AWS CLI のプロファイルを理解する

この文書では、AWS CLI を使い始めた人に向けて、次の名前や設定の関係を説明します。

- `~/.aws/config`
- `~/.aws/credentials`
- AWS CLI のプロファイル
- IAM ユーザーと MFA
- IAM Identity Center（SSO）
- `sso-session`
- このプロジェクトで使う `-mfa`、`-sso` という名前

最初に覚えておきたいのは、**プロファイルは AWS アカウントそのものではなく、AWS へ接続するための設定につけた名前**だということです。

## プロファイルとは

AWS CLI で次のコマンドを実行するとします。

```bash
aws s3 ls --profile dev
```

この `--profile dev` は、「`dev` という名前で保存した接続設定を使う」という意味です。

1 つの AWS アカウントに複数のプロファイルを作ることも、複数の AWS アカウント用の設定を使い分けることもできます。たとえば、次のような分け方ができます。

```text
dev-readonly   開発アカウントを読み取り専用で使う設定
dev-admin      開発アカウントを管理者権限で使う設定
prod-readonly  本番アカウントを読み取り専用で使う設定
```

これらの名前は手元の AWS CLI に保存する名前であり、AWS 側に同じ名前のユーザーが作られるわけではありません。

## 設定を保存する 2 つのファイル

AWS CLI の設定は、主に次の 2 ファイルに保存されます。

| ファイル | 主な内容 | 初心者向けのイメージ |
| --- | --- | --- |
| `~/.aws/config` | リージョン、出力形式、MFA デバイス、SSO 設定など | 接続方法を書いた説明書 |
| `~/.aws/credentials` | アクセスキー、シークレットアクセスキー、セッショントークンなど | 接続に使う鍵 |

同じプロファイルの情報が、内容に応じて 2 ファイルに分かれることがあります。

たとえば、`dev` という IAM ユーザー用プロファイルは次のようになります。

```ini
# ~/.aws/config
[profile dev]
region = ap-northeast-1
mfa_serial = arn:aws:iam::123456789012:mfa/my-device
```

```ini
# ~/.aws/credentials
[dev]
aws_access_key_id = AKIA...
aws_secret_access_key = ...
```

セクションの表記は違いますが、どちらも同じ `dev` プロファイルの情報です。

```text
~/.aws/config                  ~/.aws/credentials
[profile dev]       ← 対応 →  [dev]
```

ここでは、次の表記の違いに注意してください。

```text
config       では [profile dev]
credentials では [dev]
```

`credentials` 側には `profile` を付けません。`default` だけは例外で、どちらのファイルでも `[default]` と書きます。

なお、すべてのプロファイルが必ず両方のファイルに現れるわけではありません。設定内容が片方にしかなければ、片方にだけセクションが存在することもあります。

## IAM ユーザーと MFA の場合

このプロジェクトで IAM ユーザーと MFA を使う場合は、役割の違う 2 つのプロファイルを使います。

```text
dev       MFA 認証を始めるための元プロファイル
dev-mfa   MFA 認証後の一時認証情報を保存するプロファイル
```

認証の流れは次のとおりです。

```text
dev に保存された長期アクセスキー
                 │
                 │ MFA コードを入力して認証
                 ▼
AWS から一時認証情報が発行される
                 │
                 ▼
dev-mfa に保存して AWS への接続に使う
```

### 元プロファイル `dev`

`dev` には、MFA 認証を始めるための情報があります。

```text
dev
├─ IAM ユーザーのアクセスキー
├─ IAM ユーザーのシークレットアクセスキー
├─ 使用する MFA デバイス
└─ デフォルトリージョンなど
```

これらは次のように 2 ファイルへ分かれます。

```text
~/.aws/config
  [profile dev]
  ├─ region
  └─ mfa_serial

~/.aws/credentials
  [dev]
  ├─ aws_access_key_id
  └─ aws_secret_access_key
```

`mfa_serial` は、「このプロファイルでは、どの登録済み MFA デバイスを使うか」を表します。これを書くだけで AWS 側に MFA デバイスが登録されるわけではありません。

### 一時プロファイル `dev-mfa`

MFA コードを使って認証すると、AWS から有効期限付きの一時認証情報が発行されます。このプロジェクトは、その認証情報を `dev-mfa` に保存します。

```ini
# ~/.aws/credentials
[dev-mfa]
aws_access_key_id = ASIA...
aws_secret_access_key = ...
aws_session_token = ...
```

長期アクセスキーと違い、一時認証情報には `aws_session_token` があります。期限が切れたら、もう一度 MFA 認証して新しい値に更新します。

このプロジェクトは、有効期限を画面に表示するための控えも保存します。

```ini
# ~/.aws/config
[profile dev-mfa]
aws_credential_expiration = 2026-09-17T12:34:56Z
```

`aws_credential_expiration` はこのプロジェクトが表示に使う項目です。AWS CLI 自身が認証の有効性を判断するための設定ではありません。

### コマンドには元の名前を指定する

`aws-login` には、一時認証情報の保存先ではなく、元プロファイルを指定します。

```bash
aws-login --profile dev
```

内部では次のように処理されます。

```text
指定したプロファイル  dev
        │
        │ MFA 認証
        ▼
接続に使うプロファイル dev-mfa
```

そのため、プロファイルの選択メニューに `dev-mfa` は表示されません。`dev-mfa` はユーザーが認証方法を選ぶための設定ではなく、一時認証情報の保存先だからです。

## IAM Identity Center（SSO）の場合

SSO は、IAM ユーザーと MFA の組み合わせとは構造が違います。

たとえば、次の設定が作られます。

```ini
# ~/.aws/config
[profile dev-sso]
sso_session = company
sso_account_id = 123456789012
sso_role_name = DeveloperAccess
region = ap-northeast-1
output = json

[sso-session company]
sso_start_url = https://example.awsapps.com/start
sso_region = ap-northeast-1
sso_registration_scopes = sso:account:access
```

ここには、役割の違う 2 種類のセクションがあります。

```text
[profile dev-sso]       AWS のどこへ、どの権限で接続するか
[sso-session company]   どの Identity Center へログインするか
```

### SSO プロファイル `dev-sso`

`dev-sso` は、AWS コマンドで直接指定するプロファイルです。

```bash
aws s3 ls --profile dev-sso
```

主な設定は次のとおりです。

| 設定 | 意味 |
| --- | --- |
| `sso_session` | 参照する SSO セッション設定の名前 |
| `sso_account_id` | 接続する AWS アカウント |
| `sso_role_name` | そのアカウントで使う権限 |
| `region` | S3 や EC2 などを操作するデフォルトリージョン |

上の例では、「`company` という SSO セッションでログインし、AWS アカウント `123456789012` の `DeveloperAccess` 権限を使う」という意味になります。

### SSO セッション `company`

`[sso-session company]` は通常のプロファイルではありません。ブラウザなどで IAM Identity Center にログインするための共通設定です。

主な設定は次のとおりです。

| 設定 | 意味 |
| --- | --- |
| `sso_start_url` | 組織の AWS アクセスポータル URL |
| `sso_region` | IAM Identity Center が設定されているリージョン |
| `sso_registration_scopes` | ログイン時に要求する権限範囲 |

`company` は手元の設定につける任意の名前です。AWS アカウント名や IAM ユーザー名ではありません。

`company` はプロファイルではないので、通常は次のようには使いません。

```bash
# company は sso-session 名であり、接続プロファイル名ではない
aws s3 ls --profile company
```

AWS コマンドに指定するのは、`dev-sso` のようなプロファイル名です。

### 1 つの SSO セッションを共有できる

SSO セッションをプロファイルとは別に持つのは、1 回の組織ログインを複数の接続設定から共有できるためです。

```ini
[profile dev-readonly]
sso_session = company
sso_account_id = 111111111111
sso_role_name = ReadOnlyAccess

[profile dev-admin]
sso_session = company
sso_account_id = 111111111111
sso_role_name = AdministratorAccess

[profile prod-readonly]
sso_session = company
sso_account_id = 222222222222
sso_role_name = ReadOnlyAccess

[sso-session company]
sso_start_url = https://example.awsapps.com/start
sso_region = ap-northeast-1
sso_registration_scopes = sso:account:access
```

関係は次のようになります。

```text
dev-readonly   ─┐
dev-admin      ─┼─→ sso-session company
prod-readonly  ─┘
```

会社のログイン先は共通ですが、プロファイルごとに AWS アカウントや権限を変えられます。

### `region` と `sso_region` の違い

名前は似ていますが、用途が違います。

| 設定 | 対象 |
| --- | --- |
| `region` | S3、EC2、SSM など、実際に利用する AWS サービス |
| `sso_region` | IAM Identity Center 自体 |

たとえば、Identity Center が `us-east-1` にあり、普段使う EC2 が東京リージョンにある場合は、次のように異なる値になることがあります。

```ini
[profile dev-sso]
region = ap-northeast-1

[sso-session company]
sso_region = us-east-1
```

### SSO は通常 `credentials` に保存しない

SSO の場合、通常は `~/.aws/credentials` に `[dev-sso]` を作りません。

ブラウザなどでログインすると、AWS CLI が SSO の認証キャッシュを管理し、必要な一時認証情報を取得するためです。

```text
~/.aws/config                  ~/.aws/credentials
[profile dev-sso]             通常は対応するセクションなし
[sso-session company]         対応するセクションなし
```

MFA の `dev-mfa` のように、一時認証情報を別のプロファイルへ保存する方式ではありません。

## `-mfa` と `-sso` は何か

次の名前に含まれる `-mfa` と `-sso` は、AWS CLI の特別な予約語ではありません。

```text
dev
dev-mfa
dev-sso
```

どれも単なるプロファイル名です。AWS CLI が名前の末尾を見て、自動的に認証方式を決めているわけではありません。

このプロジェクトでは、それぞれの役割を分かりやすくし、IAM と SSO の設定を同時に持てるように、次の命名規則を使います。

| 名前 | このプロジェクトでの役割 |
| --- | --- |
| `dev` | IAM ユーザーと MFA の元プロファイル |
| `dev-mfa` | MFA 認証後の一時認証情報の保存先 |
| `dev-sso` | SSO で接続するプロファイル |

たとえば、次の 2 コマンドは同じ用途名 `dev` を使いながら、別の認証方式を選べます。

```bash
# IAM ユーザー + MFA
aws-login mfa --profile dev

# IAM Identity Center（SSO）
aws-login sso --profile dev
```

SSO を明示した後者では、このプロジェクトが `dev-sso` を設定・使用します。

```text
aws-login mfa --profile dev
  元の設定   dev
  接続先     dev-mfa

aws-login sso --profile dev
  SSO 設定   dev-sso
  接続先     dev-sso
```

すでに `-sso` の付かない SSO プロファイルを使っている場合、このプロジェクトが強制的に改名することはありません。方式を省略してその既存プロファイルを指定すれば、その名前のまま利用します。

## 全体の対応関係

IAM ユーザーと MFA の場合は、元プロファイルから一時プロファイルを作ります。

```text
~/.aws/config                  ~/.aws/credentials

[profile dev]       ← 対応 →  [dev]
  region                         長期アクセスキー
  mfa_serial                     シークレットアクセスキー
       │
       │ MFA 認証
       ▼
[profile dev-mfa]   ← 対応 →  [dev-mfa]
  有効期限の控え                一時アクセスキー
                                一時シークレットアクセスキー
                                セッショントークン
```

SSO の場合は、接続プロファイルから共通のログイン設定を参照します。

```text
~/.aws/config

[profile dev-sso]
  AWS アカウント
  ロール
  利用先リージョン
       │
       │ sso_session = company
       ▼
[sso-session company]
  ログイン URL
  Identity Center のリージョン

~/.aws/credentials
  通常は dev-sso 用のセクションなし
```

## よくある疑問

### `config` と `credentials` の名前は必ず揃いますか

同じプロファイルの設定が両方にある場合は、名前が対応します。

```text
[profile dev]     と [dev]
[profile dev-mfa] と [dev-mfa]
```

ただし、プロファイルが必ず両方のファイルに存在するとは限りません。たとえば SSO プロファイルは通常 `config` にだけ存在します。

### `sso-session company` もプロファイルですか

いいえ。`sso-session` は、SSO プロファイルから参照される共通ログイン設定です。

```text
プロファイル     dev-sso
SSO セッション   company
```

AWS コマンドの `--profile` には通常 `dev-sso` を指定します。

### `dev-mfa` を直接指定してもよいですか

AWS CLI のコマンドには指定できます。

```bash
aws sts get-caller-identity --profile dev-mfa
```

ただし `aws-login` には元の `dev` を指定します。`aws-login` が認証情報の有効性を確認し、必要なら MFA 認証して `dev-mfa` を更新するためです。

### 設定ファイルを直接編集してもよいですか

AWS CLI 自体は設定ファイルの直接編集にも対応していますが、このプロジェクトでは AWS CLI のコマンドを使って確認・設定することを前提にしています。

名前だけを確認する場合は、認証情報を画面に表示しない次のコマンドを使えます。

```bash
aws configure list-profiles
```

個別の設定値は次のように確認できます。

```bash
aws configure get region --profile dev
aws configure get mfa_serial --profile dev
aws configure get sso_session --profile dev-sso
```

## 覚え方

- プロファイルは「AWS への接続設定につけた名前」
- `config` は接続方法、`credentials` は接続に使う鍵
- 同じプロファイルは `[profile dev]` と `[dev]` のように名前が対応する
- IAM + MFA は「元の `dev` から、一時的な `dev-mfa` を作る」
- SSO は「`dev-sso` から、共通の `sso-session` を参照する」
- `sso-session` は接続プロファイルではなく、組織へのログイン設定
- `-mfa` と `-sso` は AWS の予約語ではなく、このプロジェクトの命名規則

このプロジェクトの正確な動作規則は [内部仕様](docs/internals.md) を、実際の使い方は [README](README.md) を参照してください。

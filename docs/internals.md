# 内部仕様

`bin/aws-login` の細かい動作規則をまとめます。普段の使い方は [README](../README.md) を参照してください。

## プロファイル名の決定

起動回数や初回起動フラグは記録しません。毎回、AWS CLI 経由でローカル設定を確認します。

名前の選択順は `--profile` → 空でない `AWS_PROFILE` → 空でない `AWS_SSO_PROFILE` です。
いずれかが指定されていれば、プロファイル名の質問は行いません。

### 未指定のとき

- 端末がある場合は `aws configure list-profiles` の一覧から選択式で質問します。
  `default` に認証設定があっても質問します。意図しないアカウントを黙って使わないためです。
- 端末がない場合は質問できないので、`default` に認証設定があればそれを使い、なければ終了します。

### 選択式メニュー

- 一覧から `-mfa` で終わる名前を除き、末尾に「新しい名前を入力」を加えて表示します。
  `-sso` で終わる名前はそのまま表示します。選べば方式も SSO と判定されます。
- 初期カーソルは `default` があればそこ、なければ先頭です。
- キー操作は ↑↓ と `j` / `k` で移動、`1`〜`9` で番号へ移動、Enter で決定、`q` または Ctrl-D で中断です。
- 一覧が空、または「新しい名前を入力」を選んだ場合は `プロファイル名 (default):` と入力を求めます。
  空 Enter で `default`、`-` で始まる入力はオプションと紛らわしいため拒否します。
- 決定後はメニューを消して「✔ プロファイル  <名前>」の 1 行に畳みます。
- 描画は ANSI エスケープシーケンス（カーソル上移動・行末消去）だけで行い、`tput` や外部ツールは使いません。
- 認証方式の質問も同じメニューです。候補は `sso` / `mfa` の 2 つで、`s` / `m` で直接選べます。

### `default` の未初期化判定（非対話時）

`default` の次の項目を確認し、一つでも空でない値があれば設定済みと扱います。

- `aws_access_key_id`、`aws_secret_access_key`、`aws_session_token`
- `mfa_serial`、`sso_session`、`sso_start_url`
- `role_arn`、`credential_process`（検出はしますが、このスクリプトでは利用対象外）

`region` / `output` だけなら未初期化として終了します。
この判定は認証設定の存在確認であり、キーが揃っていることや認証の有効性を保証しません。

### 方式の判定

設定済みなら `sso_session` / `sso_start_url` から SSO、
`mfa_serial`（または指定された MFA デバイス）から MFA を判定します。
判定できない場合は端末で方式をメニューで質問します。`mfa` / `sso` を先頭に指定することもできます。
プロファイル名を質問した場合も同じ規則で、入力した名前の設定から判定できれば方式は質問しません。

### `-sso` 接尾辞の規則

- SSO を明示指定・対話選択した場合は、`--profile` や環境変数で指定した名前にも `-sso` を追加します。
  例: `aws-login sso --profile myproj` は `myproj-sso` を確認・設定し、MFA 用の `myproj` は変更しません。
- 入力名が既に `-sso` で終わる場合は重ねて付けません。
- 方式を省略して既存の SSO 設定を自動判定した場合は、既存の名前をそのまま使います。
- 既存の接尾辞なし SSO プロファイルは移行・改名しません。

| 実行例 | 認証設定の確認対象 | 接続に使うプロファイル |
| --- | --- | --- |
| `aws-login mfa --profile myproj` | `myproj` の長期キー・MFA デバイス | `myproj-mfa`（既定） |
| `aws-login sso --profile myproj` | `myproj-sso` の SSO 設定 | `myproj-sso` |
| `aws-login sso --profile myproj-sso` | `myproj-sso` の SSO 設定 | `myproj-sso` |
| `aws-login --profile myproj` | まず `myproj` から方式を判定 | MFA なら `myproj-mfa`、既存 SSO なら `myproj` |

方式未指定で `myproj` から判定できなければ方式を質問し、SSO を選んだ時点で `myproj-sso` を確認します。
`myproj-sso` だけが設定済みでも、`--profile myproj` ではそこまで自動探索しません。

## 保存先ファイル

`AWS_SHARED_CREDENTIALS_FILE` / `AWS_CONFIG_FILE` が設定されていれば、AWS CLI はその指定先を使います。

| ファイル | `myproj` のセクション | 内容 |
| --- | --- | --- |
| `~/.aws/credentials` | `[myproj]` | 長期アクセスキー・シークレットキー |
| `~/.aws/config` | `[profile myproj]` | `mfa_serial`、region、output など |
| `~/.aws/credentials` | `[myproj-mfa]` | MFA 認証後の一時キーとセッショントークン |
| `~/.aws/config` | `[profile myproj-sso]` | SSO セッションへの参照、AWS アカウント・ロールなど |
| `~/.aws/config` | `[sso-session myproj]` | SSO の開始 URL とリージョン。複数プロファイルで共有可 |

`default` の場合は、どちらのファイルも `[default]` です。
認証情報を表示せず名前を確認するには `aws configure list-profiles` を使います。

### MFA の保存先

- 既定は `<元>-mfa` です。`--output-profile` / `AWS_MFA_PROFILE` で変更できます。
- 元と同じ保存先、長期アクセスキーや他方式の設定がある保存先は拒否します。
- 保存先が `~/.aws/config` に見つからなくても、credentials にあれば利用できます。
- 保存先の region/output は追加設定せず、実行時に元のプロファイル等から解決したリージョンを渡します。
- `[default-mfa]` だけ削除しても `[default]` の設定は残ります。次回は名前やデバイスを聞き直さず、
  MFA トークンの入力だけで一時認証情報を再作成します。

### SSO の保存先

- 認証キャッシュは AWS CLI が管理し、別の保存先プロファイルは作りません。
- SSO の対象にアクセスキーが残っている場合や、別方式の設定が検出された場合は停止します。
- MFA と併用する場合は `mfa --profile myproj` と `sso --profile myproj` を使い分けます。

## 認証の再利用

有効な認証は `sts get-caller-identity` で確認して再利用し、期限切れや認証キャッシュがない場合はログインします。
通信・権限など、それ以外の確認エラーでは原因を表示して終了します。
`--duration-seconds` を指定するか、設定済みと異なる MFA デバイスを指定した場合も再ログインします。

## 有効期限の表示

ログイン後、または再利用時に、認証情報の有効期限と残り時間をローカル時刻で表示します。
期限が分からない場合は表示を省略し、処理は続行します。期限の判定そのものは STS の結果に任せます。

| 方式 | 期限の取得元 |
| --- | --- |
| MFA | 保存先プロファイルの `aws_credential_expiration` |
| SSO | `aws configure export-credentials --profile <名前>` の `Expiration` |

`aws configure mfa-login` は一時認証情報に期限を保存しません。
そのため、ラッパーはログイン時の出力にある `Credentials will expire at ... UTC` の行を読み取り、
保存先プロファイルに `aws_credential_expiration` として ISO 8601（UTC）で書き込みます。
この項目は AWS CLI 自身は参照しない、このスクリプト専用の控えです。
標準コマンドで直接ログインした場合は書き込まれないため、表示は省略されます。

日時の変換には `date` を使い、GNU date と BSD date（macOS 標準）の両方に対応します。

## 表示の規則

経過はすべて標準エラーに出し、標準出力は後続コマンドのために空けておきます。
例外は、後続コマンドを指定しなかったときの「次に打つコマンド」の案内だけです。

| 記号 | 意味 |
| --- | --- |
| `◆` | 見出し（太字） |
| `✔` | 済んだこと（緑）。「ラベル  値」の 2 列で、値は太字 |
| `●` | これから行うこと（シアン）。AWS CLI のウィザードやログインの直前に出す |
| `❯` | 入力を求める行とメニューのカーソル（シアン）。答えた後は `✔` の 1 行に畳む |
| `✗` | 失敗（赤）。終了コード 2 |

- 有効期限が切れている可能性があるときは、記号を足さず値だけを黄色にします。
- ラベルは幅 18 に揃えます。日本語は 1 文字を幅 2 として数えます。
- 補足と AWS CLI の生のエラー文は薄い色で字下げして出します。
- 色は出力先が端末で、`NO_COLOR` が未設定かつ `TERM` が `dumb` でないときだけ付けます。
  端末でなければ記号付きの素の文字列になります。メニューと入力行の畳み込みも端末のときだけです。
- テストは `NO_COLOR=1` で実行し、文言だけを検証します。

## 標準コマンドとの対応

ラッパーは内部で AWS CLI の標準コマンドを呼び出します。手動で同じことをする場合の対応表です。

### MFA

| ラッパー | 標準コマンド |
| --- | --- |
| 初回設定（アクセスキー） | `aws configure --profile dev` |
| 初回設定（MFA デバイス） | `aws configure set mfa_serial arn:aws:iam::123456789012:mfa/my-device --profile dev` |
| ログイン | `aws configure mfa-login --profile dev --update-profile dev-mfa`（加えて期限を `aws_credential_expiration` に保存） |
| 確認 | `aws sts get-caller-identity --profile dev-mfa` |
| `--output-profile` | `--update-profile` |
| `--mfa-serial` | `--serial-number` |
| `--duration-seconds` | `--duration-seconds` |

`mfa_serial` は登録済みデバイスをローカルのプロファイルに関連付ける設定で、
AWS 側にデバイスを登録する操作ではありません。
`--update-profile` を省略した場合の保存先は AWS CLI が決めるため、ラッパーと揃えるなら明示してください。

### SSO

| ラッパー | 標準コマンド |
| --- | --- |
| 初回設定 | `aws configure sso --profile dev-sso` |
| ログイン | `aws sso login --profile dev-sso` |
| 確認 | `aws sts get-caller-identity --profile dev-sso` |
| `--use-device-code` / `--no-browser` | 同名オプションを設定とログインの両方に渡す |

ウィザードの主な入力項目は以下のとおりです。

| 項目 | 入力するもの |
| --- | --- |
| SSO session name | ローカルのログイン設定に付ける任意の名前。例: `myproj` |
| SSO start URL | 組織の AWS アクセスポータル URL。例: `https://d-xxxxxxxxxx.awsapps.com/start` |
| SSO region | IAM Identity Center を設定しているリージョン。EC2 などの利用先リージョンとは別の設定 |

IAM Identity Center 自体は追加料金なしです。カスタマー管理 KMS キーや、接続先の AWS リソースなどは別料金です。
詳細は [公式 FAQ](https://aws.amazon.com/jp/iam/identity-center/faqs/) と
[暗号化の料金](https://docs.aws.amazon.com/singlesignon/latest/userguide/encryption-at-rest.html) を参照してください。

## 後続コマンドの実行

- 後続コマンドには実行用の `AWS_PROFILE` / `AWS_DEFAULT_PROFILE` と、解決できたリージョンを渡します。
- コマンド自身で別の `--profile` や認証情報を指定するとそちらが優先されます。
- 標準出力と終了コードは後続コマンドのものを保ちます。コマンドを指定しない場合は、認証済みプロファイル名と実行例を表示します。
- スクリプト内ではアクセスキー環境変数と Web Identity 用のロール関連環境変数を解除します。
  親シェルの環境は変更しないため、`source` せずに実行してください。
- 単独で `aws-login` を実行しても、その後に別途実行する `ssh` などの環境は変わりません。

## 対象外

- AssumeRole / `credential_process` プロファイル
- SSO や AssumeRole の一時認証情報を MFA の元プロファイルに使うこと
- AWS 側のユーザー作成、アクセスキー発行、MFA 登録、SSO 有効化、権限割り当て
- AWS CLI のインストール

## リリース

Homebrew での配布と手順は [docs/release.md](release.md) にあります。

#!/usr/bin/env bash
#
# テスト共通のセットアップとアサーション。tests/run.sh から読み込む。
#
# テスト関数は 1 件ずつサブシェルで実行し、その中では set -e が有効になっている。
# アサーションは失敗時に理由を表示して 1 を返すため、そこでテストが打ち切られる。

# 1 件分の作業ディレクトリを用意し、環境を既知の状態に揃える。
setup_workspace() {
  # TMPDIR の末尾スラッシュを持ち込まないよう、作った場所へ移動して絶対パスを取り直す。
  WORK=$(cd -- "$(mktemp -d "${TMPDIR:-/tmp}/aws-login-test.XXXXXX")" && pwd)
  export AWS_MOCK_DIR="$WORK/mock"
  mkdir -p "$AWS_MOCK_DIR/profiles" "$AWS_MOCK_DIR/sessions"
  : > "$AWS_MOCK_DIR/log"

  # 実行環境の設定がテスト結果に影響しないようにする。
  unset AWS_PROFILE AWS_SSO_PROFILE AWS_MFA_PROFILE AWS_MFA_SERIAL
  unset AWS_REGION AWS_DEFAULT_REGION AWS_SESSION_TOKEN AWS_SECRET_ACCESS_KEY
  unset AWS_MOCK_STS_ERROR AWS_MOCK_LOGIN_EXIT AWS_MOCK_NO_MFA_LOGIN

  # 擬似端末でも色の制御コードを出さず、文言だけで検証できるようにする。
  export NO_COLOR=1

  # 呼び出し元の認証情報を解除しているかを模擬 CLI 側で検査させる。
  export AWS_ACCESS_KEY_ID=leaked-from-caller

  export PATH="$TESTS_DIR/bin:$ORIGINAL_PATH"
}

teardown_workspace() {
  [[ -z "${WORK:-}" || ! -d "$WORK" ]] || rm -rf "$WORK"
}

#--- 事前条件 ----------------------------------------------------------------

# プロファイルの設定を作る。例: given_profile dev mfa_serial=device region=ap-northeast-1
given_profile() {
  local name=$1 entry
  shift
  : >> "$AWS_MOCK_DIR/profiles/$name"
  for entry in "$@"; do
    printf '%s\n' "$entry" >> "$AWS_MOCK_DIR/profiles/$name"
  done
}

# 長期アクセスキーを持つ IAM ユーザーのプロファイルを作る。
given_iam_profile() {
  given_profile "$1" aws_access_key_id=AKIAEXAMPLE aws_secret_access_key=secret "${@:2}"
}

# MFA 認証後の一時認証情報が保存済みのプロファイルを作る。
given_mfa_session_profile() {
  given_profile "$1" aws_access_key_id=ASIAEXAMPLE aws_session_token=session "${@:2}"
}

# SSO 設定済みのプロファイルを作る。
given_sso_profile() {
  given_profile "$1" sso_session=corp "${@:2}"
}

# 認証情報が期限切れである（=ログインが必要である）状態にする。
given_expired_credentials() {
  export AWS_MOCK_STS_ERROR=${1:-'An error occurred (ExpiredToken) when calling the operation'}
}

# ログイン済みとして扱うプロファイルを登録する。
given_logged_in() {
  touch "$AWS_MOCK_DIR/sessions/$1"
}

#--- 実行 --------------------------------------------------------------------

# bin/aws-login を非対話（端末なし）で実行し、結果を STATUS / STDOUT / STDERR に入れる。
run_login() {
  local status=0
  bash "$ROOT/bin/aws-login" "$@" > "$WORK/stdout" 2> "$WORK/stderr" < /dev/null || status=$?
  STATUS=$status
  STDOUT=$(cat "$WORK/stdout")
  STDERR=$(cat "$WORK/stderr")
}

# 擬似端末を用意して bin/aws-login を実行する。第 1 引数はプロンプトへ与える入力。
# 標準出力と標準エラーは端末上で混ざるため、まとめて OUTPUT に入れる。
run_login_on_terminal() {
  local input=$1 status=0
  shift
  {
    sleep 0.4
    printf '%s' "$input"
    sleep 0.8
  } | script -q /dev/null bash "$ROOT/bin/aws-login" "$@" > "$WORK/tty" 2>&1 || status=$?
  STATUS=$status
  OUTPUT=$(tr -d '\r' < "$WORK/tty")
}

# 擬似端末が使えない環境ではテストを飛ばす。
require_terminal_support() {
  script -q /dev/null true < /dev/null > /dev/null 2>&1 ||
    skip_test '擬似端末 (script) が使えません'
}

#--- アサーション ------------------------------------------------------------

report_failure() {
  printf '    %s\n' "$@" >&2
  return 1
}

assert_status() {
  local expected=$1
  (( STATUS == expected )) ||
    report_failure "終了コードが $expected ではなく $STATUS でした" "stderr: $STDERR"
}

assert_success() {
  (( STATUS == 0 )) ||
    report_failure "成功するはずが終了コード $STATUS で失敗しました" "stderr: $STDERR"
}

assert_failure() {
  (( STATUS != 0 )) ||
    report_failure '失敗するはずが成功しました' "stdout: $STDOUT"
}

assert_contains() {
  local haystack=$1 needle=$2 label=${3:-出力}
  [[ "$haystack" == *"$needle"* ]] ||
    report_failure "${label} に「${needle}」が含まれていません" "実際: ${haystack}"
}

assert_not_contains() {
  local haystack=$1 needle=$2 label=${3:-出力}
  [[ "$haystack" != *"$needle"* ]] ||
    report_failure "${label} に「${needle}」が含まれていました" "実際: ${haystack}"
}

assert_stdout_contains() { assert_contains "$STDOUT" "$1" '標準出力'; }
assert_stderr_contains() { assert_contains "$STDERR" "$1" '標準エラー'; }
assert_stderr_not_contains() { assert_not_contains "$STDERR" "$1" '標準エラー'; }

assert_equals() {
  local expected=$1 actual=$2 label=${3:-値}
  [[ "$expected" == "$actual" ]] ||
    report_failure "${label} が「${expected}」ではなく「${actual}」でした"
}

# 模擬 CLI の呼び出しログ。1 行 1 呼び出し。
aws_calls() {
  cat "$AWS_MOCK_DIR/log"
}

# 指定の正規表現に一致する aws 呼び出しがあることを確かめる。
assert_aws_called() {
  grep -qE -- "$1" "$AWS_MOCK_DIR/log" ||
    report_failure "aws の呼び出しに /$1/ が見つかりません" "呼び出し: $(aws_calls | tr '\n' '|')"
}

assert_aws_not_called() {
  ! grep -qE -- "$1" "$AWS_MOCK_DIR/log" ||
    report_failure "aws の呼び出しに /$1/ が含まれていました" "呼び出し: $(aws_calls | tr '\n' '|')"
}

# プロファイルに保存された設定値を確かめる。
assert_profile_value() {
  local name=$1 key=$2 expected=$3 actual=
  if [[ -f "$AWS_MOCK_DIR/profiles/$name" ]]; then
    actual=$(grep -m1 "^$key=" "$AWS_MOCK_DIR/profiles/$name" || true)
    actual=${actual#*=}
  fi
  assert_equals "$expected" "$actual" "プロファイル $name の $key"
}

# 「ラベル  値」の 2 列表示があることを確かめる。ラベルと値の間の空白の数は問わない。
assert_shows() {
  local haystack=$1 label=$2 value=$3 stream=${4:-出力} pattern
  pattern="$(escape_regex "$label") +$(escape_regex "$value")"
  grep -qE -- "$pattern" <<< "$haystack" ||
    report_failure "${stream} に「${label}  ${value}」の行がありません" "実際: ${haystack}"
}

escape_regex() {
  # 単一引用符の中身は sed のスクリプト。$ は文字クラス内のリテラルで、シェルに展開させてはいけない。
  # shellcheck disable=SC2016
  printf '%s' "$1" | sed 's#[][\.*^$()+?{}|]#\\&#g'
}

assert_stdout_shows() { assert_shows "$STDOUT" "$1" "$2" '標準出力'; }
assert_stderr_shows() { assert_shows "$STDERR" "$1" "$2" '標準エラー'; }
assert_output_shows() { assert_shows "$OUTPUT" "$1" "$2" '端末出力'; }

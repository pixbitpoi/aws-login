#!/usr/bin/env bash
#
# 引数とオプションの解析。

test_arguments_help_lists_usage() {
  run_login --help

  assert_success
  assert_stdout_contains '使用方法: aws-login'
  assert_stdout_contains '--output-profile'
  assert_aws_not_called '.'
}

test_arguments_short_help_option() {
  run_login -h

  assert_success
  assert_stdout_contains '使用方法: aws-login'
}

test_arguments_unknown_option_is_rejected() {
  run_login --bogus

  assert_status 2
  assert_stderr_contains '不明な引数: --bogus'
}

test_arguments_option_requires_a_value() {
  run_login --profile

  assert_status 2
  assert_stderr_contains '--profile に値が必要です。'
}

test_arguments_option_rejects_a_flag_as_value() {
  run_login --region --refresh

  assert_status 2
  assert_stderr_contains '--region に値が必要です。'
}

test_arguments_separator_requires_a_command() {
  given_sso_profile dev-sso

  run_login --profile dev-sso --

  assert_status 2
  assert_stderr_contains '-- の後にコマンドが必要です。'
}

test_arguments_later_option_wins_over_environment() {
  given_sso_profile dev-sso
  export AWS_PROFILE=other

  run_login --profile dev-sso

  assert_success
  assert_stderr_shows '接続プロファイル' 'dev-sso (sso)'
}

test_arguments_missing_aws_cli_is_reported() {
  # aws が見つからない PATH で実行する。bash 自身は絶対パスで起動する。
  local status=0
  PATH=/var/empty "$BASH" "$ROOT/bin/aws-login" --profile dev-sso \
    > "$WORK/stdout" 2> "$WORK/stderr" < /dev/null || status=$?

  assert_equals 2 "$status" '終了コード'
  assert_contains "$(cat "$WORK/stderr")" 'AWS CLI v2 をインストールしてください。' '標準エラー'
}

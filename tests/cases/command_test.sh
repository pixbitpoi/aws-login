#!/usr/bin/env bash
#
# -- の後に指定した後続コマンドへの引き継ぎ。
#
# bash -c に渡す単一引用符の中身は、aws-login が起動した子プロセスで展開されることを確かめる本体。
# ここでシェルに展開させるとテストの意味が無くなるため、ファイル全体で SC2016 を抑止する。
# shellcheck disable=SC2016

test_command_receives_the_effective_profile() {
  given_iam_profile dev mfa_serial=device
  given_mfa_session_profile dev-mfa

  run_login --profile dev -- bash -c 'printf "%s %s\n" "$AWS_PROFILE" "$AWS_DEFAULT_PROFILE"'

  assert_success
  assert_equals 'dev-mfa dev-mfa' "$STDOUT" '後続コマンドが見たプロファイル'
}

test_command_receives_the_resolved_region() {
  given_sso_profile dev-sso region=ap-northeast-1

  run_login --profile dev-sso -- bash -c 'printf "%s %s\n" "$AWS_REGION" "$AWS_DEFAULT_REGION"'

  assert_success
  assert_equals 'ap-northeast-1 ap-northeast-1' "$STDOUT" '後続コマンドが見たリージョン'
}

test_command_does_not_receive_static_credentials() {
  given_sso_profile dev-sso

  run_login --profile dev-sso -- bash -c 'printf "[%s]\n" "${AWS_ACCESS_KEY_ID:-}${AWS_SESSION_TOKEN:-}"'

  assert_success
  assert_equals '[]' "$STDOUT" '後続コマンドが見た認証情報'
}

test_command_exit_status_is_preserved() {
  given_sso_profile dev-sso

  run_login --profile dev-sso -- bash -c 'exit 37'

  assert_status 37
}

test_command_stdout_is_not_polluted() {
  given_sso_profile dev-sso

  run_login --profile dev-sso -- printf 'only-this\n'

  assert_success
  assert_equals 'only-this' "$STDOUT" '標準出力'
}

test_command_arguments_are_passed_verbatim() {
  given_sso_profile dev-sso

  run_login --profile dev-sso -- bash -c 'printf "%s\n" "$@"' _ --profile other 'a b'

  assert_success
  assert_equals '--profile
other
a b' "$STDOUT" '後続コマンドの引数'
}

test_command_hint_is_printed_without_a_command() {
  given_iam_profile dev mfa_serial=device
  given_mfa_session_profile dev-mfa

  run_login --profile dev

  assert_success
  assert_stdout_shows '認証済み' 'dev-mfa'
  assert_stdout_contains 'aws --profile dev-mfa s3 ls'
  assert_stdout_contains 'aws-login --profile dev -- aws s3 ls'
}

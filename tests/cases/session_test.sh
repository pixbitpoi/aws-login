#!/usr/bin/env bash
#
# STS による認証確認、リージョンの解決、呼び出し元の環境の扱い。

test_session_expired_messages_trigger_login() {
  # 期限切れ・キャッシュなしを示すメッセージは、いずれもログインへ進む。
  local message
  for message in \
    'An error occurred (ExpiredToken)' \
    'An error occurred (InvalidClientTokenId)' \
    'UnauthorizedSSOTokenError' \
    'Token has expired and refresh failed' \
    'Token does not exist' \
    'Error loading SSO Token' \
    'The SSO session associated with this profile has expired' \
    'Unable to locate credentials'
  do
    teardown_workspace
    setup_workspace
    given_sso_profile dev-sso
    given_expired_credentials "$message"

    run_login --profile dev-sso

    assert_success
    assert_aws_called 'sso login --profile dev-sso'
  done
}

test_session_network_error_stops_without_login() {
  given_sso_profile dev-sso
  given_expired_credentials 'Could not connect to the endpoint URL'

  run_login --profile dev-sso

  assert_status 2
  assert_stderr_contains 'Could not connect to the endpoint URL'
  assert_stderr_contains '認証確認に失敗しました。'
  assert_aws_not_called 'sso login'
}

test_session_permission_error_stops_without_login() {
  given_sso_profile dev-sso
  given_expired_credentials 'An error occurred (AccessDenied) when calling the GetCallerIdentity operation'

  run_login --profile dev-sso

  assert_status 2
  assert_stderr_contains '認証確認に失敗しました。'
  assert_aws_not_called 'sso login'
}

test_session_login_failure_exit_code_is_kept() {
  given_sso_profile dev-sso
  export AWS_MOCK_LOGIN_EXIT=42

  run_login --profile dev-sso --refresh

  assert_status 42
}

test_session_identity_is_reported() {
  given_sso_profile dev-sso

  run_login --profile dev-sso

  assert_success
  assert_stderr_shows 'アカウント' '123456789012'
  assert_stderr_shows 'ARN' 'arn:aws:iam::123456789012:user/test'
}

test_session_is_verified_again_after_login() {
  given_sso_profile dev-sso
  given_expired_credentials

  run_login --profile dev-sso

  assert_success
  # ログイン前後で 1 回ずつ確認する。
  assert_equals 2 "$(aws_calls | grep -c 'sts get-caller-identity')" 'sts の呼び出し回数'
}

test_session_caller_credentials_are_unset() {
  given_sso_profile dev-sso

  run_login --profile dev-sso

  # 模擬 CLI は AWS_ACCESS_KEY_ID などが残っていると終了コード 90 で失敗する。
  assert_success
  assert_equals leaked-from-caller "$AWS_ACCESS_KEY_ID" '呼び出し元の AWS_ACCESS_KEY_ID'
}

test_session_region_option_is_passed() {
  given_sso_profile dev-sso

  run_login --profile dev-sso --region us-east-1

  assert_success
  assert_aws_called 'sts get-caller-identity --profile dev-sso --region us-east-1'
}

test_session_region_environment_is_used() {
  given_sso_profile dev-sso
  export AWS_REGION=eu-west-1

  run_login --profile dev-sso

  assert_success
  assert_aws_called 'sts get-caller-identity --profile dev-sso --region eu-west-1'
}

test_session_default_region_environment_is_used() {
  given_sso_profile dev-sso
  export AWS_DEFAULT_REGION=eu-west-1

  run_login --profile dev-sso

  assert_success
  assert_aws_called 'sts get-caller-identity --profile dev-sso --region eu-west-1'
}

test_session_region_falls_back_to_profile_setting() {
  given_sso_profile dev-sso region=ap-northeast-1

  run_login --profile dev-sso

  assert_success
  assert_aws_called 'sts get-caller-identity --profile dev-sso --region ap-northeast-1'
}

test_session_region_is_omitted_when_unknown() {
  given_sso_profile dev-sso

  run_login --profile dev-sso

  assert_success
  assert_aws_not_called '\-\-region'
}

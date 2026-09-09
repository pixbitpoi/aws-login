#!/usr/bin/env bash
#
# IAM Identity Center (SSO) の準備とログイン。

test_sso_reuses_valid_session() {
  given_sso_profile dev-sso

  run_login --profile dev-sso

  assert_success
  assert_stderr_shows '認証情報を再利用' 'dev-sso'
  assert_aws_not_called 'sso login'
}

test_sso_logs_in_when_session_expired() {
  given_sso_profile dev-sso
  given_expired_credentials 'Error loading SSO Token: Token for does not exist'

  run_login --profile dev-sso

  assert_success
  assert_aws_called 'sso login --profile dev-sso'
  assert_stderr_shows '接続プロファイル' 'dev-sso (sso)'
}

test_sso_refresh_forces_login() {
  given_sso_profile dev-sso

  run_login --profile dev-sso --refresh

  assert_success
  assert_aws_called 'sso login --profile dev-sso'
  assert_stderr_not_contains '認証情報を再利用'
}

test_sso_browser_options_are_passed_to_login() {
  given_sso_profile dev-sso

  run_login --profile dev-sso --refresh --use-device-code --no-browser

  assert_success
  assert_aws_called 'sso login --profile dev-sso .*--use-device-code --no-browser'
}

test_sso_rejects_output_profile_option() {
  given_sso_profile dev-sso

  run_login --profile dev-sso --output-profile dev-mfa

  assert_status 2
  assert_stderr_contains 'MFA 専用オプション・環境変数は SSO に使えません。'
}

test_sso_rejects_mfa_serial_option() {
  given_sso_profile dev-sso

  run_login sso --profile dev-sso --mfa-serial device

  assert_status 2
  assert_stderr_contains 'MFA 専用オプション・環境変数は SSO に使えません。'
}

test_sso_rejects_duration_option() {
  given_sso_profile dev-sso

  run_login --profile dev-sso --duration-seconds 900

  assert_status 2
  assert_stderr_contains 'MFA 専用オプション・環境変数は SSO に使えません。'
}

test_sso_rejects_mfa_environment_variables() {
  given_sso_profile dev-sso
  export AWS_MFA_PROFILE=dev-mfa

  run_login --profile dev-sso

  assert_status 2
  assert_stderr_contains 'MFA 専用オプション・環境変数は SSO に使えません。'
}

test_sso_rejects_profile_holding_access_keys() {
  given_sso_profile dev-sso aws_access_key_id=AKIAEXAMPLE

  run_login --profile dev-sso

  assert_status 2
  assert_stderr_contains '保存先 dev-sso にアクセスキーがあります。'
}

test_sso_setup_needs_a_terminal() {
  # 未設定なら aws configure sso のウィザードが必要になる。非対話では案内して終了する。
  run_login sso --profile new

  assert_status 2
  assert_stderr_contains '端末から再実行してください: SSO の設定'
  assert_aws_not_called 'configure sso'
}

test_sso_does_not_touch_the_mfa_source_profile() {
  given_iam_profile dev mfa_serial=device
  given_sso_profile dev-sso

  run_login sso --profile dev --refresh

  assert_success
  assert_aws_called 'sso login --profile dev-sso'
  assert_aws_not_called 'configure mfa-login'
  assert_aws_not_called '\-\-profile dev( |$)'
}

test_sso_reports_expiration_from_export_credentials() {
  given_sso_profile dev-sso
  export AWS_MOCK_EXPIRATION='2099-01-02 03:04:05'

  run_login --profile dev-sso

  assert_success
  assert_aws_called 'configure export-credentials --profile dev-sso'
  assert_stderr_contains '有効期限'
  assert_stderr_contains '残り '
}

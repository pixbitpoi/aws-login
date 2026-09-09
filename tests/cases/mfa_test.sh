#!/usr/bin/env bash
#
# MFA（IAM ユーザー + 一時認証情報）の準備とログイン。

# 元プロファイルと、有効な一時認証情報の保存先を用意する。
setup_mfa_profiles() {
  given_iam_profile dev mfa_serial=arn:aws:iam::123456789012:mfa/device
  given_mfa_session_profile dev-mfa
}

test_mfa_reuses_stored_session() {
  setup_mfa_profiles

  run_login --profile dev

  assert_success
  assert_stderr_shows '認証情報を再利用' 'dev-mfa'
  assert_aws_not_called 'configure mfa-login --profile'
}

test_mfa_logs_in_when_output_profile_is_empty() {
  given_iam_profile dev mfa_serial=arn:aws:iam::123456789012:mfa/device

  run_login --profile dev

  assert_success
  assert_aws_called 'configure mfa-login --profile dev .*--serial-number arn:aws:iam::123456789012:mfa/device'
  assert_aws_called 'configure mfa-login --profile dev .*--update-profile dev-mfa'
  assert_stderr_shows '接続プロファイル' 'dev-mfa (mfa)'
}

test_mfa_logs_in_when_session_expired() {
  setup_mfa_profiles
  given_expired_credentials

  run_login --profile dev

  assert_success
  assert_aws_called 'configure mfa-login --profile dev '
}

test_mfa_refresh_forces_login() {
  setup_mfa_profiles

  run_login --profile dev --refresh

  assert_success
  assert_aws_called 'configure mfa-login --profile dev '
  assert_stderr_not_contains '認証情報を再利用'
}

test_mfa_login_support_is_checked_first() {
  given_iam_profile dev mfa_serial=device
  export AWS_MOCK_NO_MFA_LOGIN=1

  run_login --profile dev

  assert_status 2
  assert_stderr_contains 'mfa-login のヘルプを実行できません。'
  assert_aws_not_called 'configure mfa-login --profile'
}

test_mfa_custom_output_profile_option() {
  given_iam_profile dev mfa_serial=device

  run_login --profile dev --output-profile dev-temp

  assert_success
  assert_aws_called 'configure mfa-login .*--update-profile dev-temp'
  assert_stderr_shows '接続プロファイル' 'dev-temp (mfa)'
}

test_mfa_output_profile_environment_is_used() {
  given_iam_profile dev mfa_serial=device
  export AWS_MFA_PROFILE=dev-temp

  run_login --profile dev

  assert_success
  assert_aws_called 'configure mfa-login .*--update-profile dev-temp'
}

test_mfa_output_profile_must_differ_from_source() {
  given_iam_profile dev mfa_serial=device

  run_login --profile dev --output-profile dev

  assert_status 2
  assert_stderr_contains '元と保存先は別のプロファイル名にしてください。'
}

test_mfa_output_profile_with_long_term_keys_is_rejected() {
  given_iam_profile dev mfa_serial=device
  given_iam_profile dev-mfa

  run_login --profile dev

  assert_status 2
  assert_stderr_contains '保存先 dev-mfa に長期アクセスキーがあります。'
}

test_mfa_output_profile_of_another_method_is_rejected() {
  given_iam_profile dev mfa_serial=device
  given_sso_profile dev-mfa

  run_login --profile dev

  assert_status 2
  assert_stderr_contains '保存先 dev-mfa は他の認証方式で使用中です。'
}

test_mfa_source_profile_with_session_token_is_rejected() {
  given_profile dev aws_access_key_id=ASIAEXAMPLE aws_session_token=temporary mfa_serial=device

  run_login --profile dev

  assert_status 2
  assert_stderr_contains '元プロファイルには長期アクセスキーが必要です。'
}

test_mfa_rejects_sso_only_options() {
  given_iam_profile dev mfa_serial=device

  run_login mfa --profile dev --no-browser

  assert_status 2
  assert_stderr_contains 'SSO 専用オプションは MFA に使えません。'
}

test_mfa_serial_option_overrides_and_forces_login() {
  setup_mfa_profiles

  run_login --profile dev --mfa-serial arn:aws:iam::123456789012:mfa/other

  assert_success
  assert_aws_called 'configure mfa-login .*--serial-number arn:aws:iam::123456789012:mfa/other'
  assert_stderr_not_contains '認証情報を再利用'
}

test_mfa_serial_environment_is_used() {
  given_iam_profile dev
  export AWS_MFA_SERIAL=arn:aws:iam::123456789012:mfa/from-env

  run_login --profile dev

  assert_success
  assert_aws_called 'configure mfa-login .*--serial-number arn:aws:iam::123456789012:mfa/from-env'
}

test_mfa_duration_is_passed_and_forces_login() {
  setup_mfa_profiles

  run_login --profile dev --duration-seconds 900

  assert_success
  assert_aws_called 'configure mfa-login .*--duration-seconds 900'
  assert_stderr_not_contains '認証情報を再利用'
}

test_mfa_missing_serial_needs_a_terminal() {
  given_iam_profile dev

  run_login mfa --profile dev

  assert_status 2
  assert_stderr_contains '登録済み MFA デバイスの ARN / シリアル番号'
}

test_mfa_missing_access_keys_needs_a_terminal() {
  given_profile dev mfa_serial=device

  run_login --profile dev

  assert_status 2
  assert_stderr_contains 'IAM ユーザーの長期アクセスキー設定'
}

test_mfa_login_saves_expiration_from_cli_output() {
  given_iam_profile dev mfa_serial=arn:aws:iam::123456789012:mfa/device
  export AWS_MOCK_EXPIRATION='2099-01-02 03:04:05'

  run_login --profile dev

  assert_success
  assert_aws_called 'configure set aws_credential_expiration 2099-01-02T03:04:05Z --profile dev-mfa'
  assert_stderr_contains '有効期限'
  assert_stderr_contains '残り '
}

test_mfa_reuse_reports_stored_expiration() {
  given_iam_profile dev mfa_serial=arn:aws:iam::123456789012:mfa/device
  given_mfa_session_profile dev-mfa aws_credential_expiration=2099-01-02T03:04:05Z

  run_login --profile dev

  assert_success
  assert_stderr_shows '認証情報を再利用' 'dev-mfa'
  assert_stderr_contains '有効期限'
  assert_aws_not_called 'configure export-credentials'
}

test_mfa_reuse_without_expiration_prints_nothing() {
  setup_mfa_profiles

  run_login --profile dev

  assert_success
  assert_stderr_not_contains '有効期限'
}

test_mfa_past_expiration_is_flagged() {
  given_iam_profile dev mfa_serial=arn:aws:iam::123456789012:mfa/device
  given_mfa_session_profile dev-mfa aws_credential_expiration=2000-01-01T00:00:00Z

  run_login --profile dev

  assert_success
  assert_stderr_contains '期限切れの可能性'
}

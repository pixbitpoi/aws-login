#!/usr/bin/env bash
#
# プロファイル名の決定と、MFA / SSO どちらを使うかの判定。

test_mode_detected_from_mfa_serial() {
  given_iam_profile dev mfa_serial=arn:aws:iam::123456789012:mfa/device
  given_mfa_session_profile dev-mfa

  run_login --profile dev

  assert_success
  assert_stderr_shows '接続プロファイル' 'dev-mfa (mfa)'
}

test_mode_detected_from_sso_session() {
  given_sso_profile dev-sso

  run_login --profile dev-sso

  assert_success
  assert_stderr_shows '接続プロファイル' 'dev-sso (sso)'
}

test_mode_detected_from_sso_start_url() {
  given_profile dev-sso sso_start_url=https://example.awsapps.com/start

  run_login --profile dev-sso

  assert_success
  assert_stderr_shows '接続プロファイル' 'dev-sso (sso)'
}

test_mode_explicit_sso_appends_suffix() {
  given_sso_profile dev-sso

  run_login sso --profile dev

  assert_success
  assert_stderr_shows '接続プロファイル' 'dev-sso (sso)'
  assert_aws_not_called '\-\-profile dev( |$)'
}

test_mode_explicit_sso_keeps_existing_suffix() {
  given_sso_profile dev-sso

  run_login sso --profile dev-sso

  assert_success
  assert_stderr_shows '接続プロファイル' 'dev-sso (sso)'
  assert_aws_not_called 'dev-sso-sso'
}

test_mode_explicit_mfa_conflicts_with_sso_settings() {
  given_sso_profile dev

  run_login mfa --profile dev

  assert_status 2
  assert_stderr_contains '設定済みの方式は sso です。'
}

test_mode_explicit_sso_conflicts_with_mfa_settings() {
  given_iam_profile dev-sso mfa_serial=device

  run_login sso --profile dev-sso

  assert_status 2
  assert_stderr_contains '設定済みの方式は mfa です。'
}

test_mode_assume_role_profile_is_rejected() {
  given_profile dev role_arn=arn:aws:iam::123456789012:role/admin

  run_login --profile dev

  assert_status 2
  assert_stderr_contains 'AssumeRole / credential_process プロファイルは対象外です。'
}

test_mode_credential_process_profile_is_rejected() {
  given_profile dev credential_process=/usr/local/bin/creds

  run_login --profile dev

  assert_status 2
  assert_stderr_contains 'AssumeRole / credential_process プロファイルは対象外です。'
}

test_mode_configured_default_profile_is_used() {
  given_iam_profile default mfa_serial=device
  given_mfa_session_profile default-mfa

  run_login

  assert_success
  assert_stderr_shows '接続プロファイル' 'default-mfa (mfa)'
}

test_mode_aws_profile_environment_is_used() {
  given_sso_profile dev-sso
  export AWS_PROFILE=dev-sso

  run_login

  assert_success
  assert_stderr_shows '接続プロファイル' 'dev-sso (sso)'
}

test_mode_aws_sso_profile_environment_is_used() {
  given_sso_profile dev-sso
  export AWS_SSO_PROFILE=dev-sso

  run_login

  assert_success
  assert_stderr_shows '接続プロファイル' 'dev-sso (sso)'
}

test_mode_aws_profile_wins_over_aws_sso_profile() {
  given_sso_profile primary-sso
  given_sso_profile secondary-sso
  export AWS_PROFILE=primary-sso AWS_SSO_PROFILE=secondary-sso

  run_login

  assert_success
  assert_stderr_shows '接続プロファイル' 'primary-sso (sso)'
}

test_mode_unconfigured_default_needs_a_terminal() {
  run_login

  assert_status 2
  assert_stderr_contains 'プロファイル名を --profile NAME で指定してください。'
}

test_mode_region_only_default_counts_as_uninitialized() {
  given_profile default region=ap-northeast-1 output=json

  run_login

  assert_status 2
  assert_stderr_contains 'プロファイル名を --profile NAME で指定してください。'
}

test_mode_undetectable_method_needs_a_terminal() {
  given_profile dev region=ap-northeast-1

  run_login --profile dev

  assert_status 2
  assert_stderr_contains 'dev の認証方式'
}

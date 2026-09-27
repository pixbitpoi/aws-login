#!/usr/bin/env bash
#
# 端末がある場合の対話セットアップ。擬似端末 (script) 上で実行する。

test_interactive_asks_for_profile_name_and_method() {
  require_terminal_support

  run_login_on_terminal 'neon
sso
'

  assert_status 0
  assert_output_shows '対象プロファイル' 'neon-sso'
  assert_output_shows '接続プロファイル' 'neon-sso (sso)'
  assert_aws_called 'configure sso --profile neon-sso'
}

test_interactive_keeps_an_existing_sso_suffix() {
  require_terminal_support

  run_login_on_terminal 'neon-sso
sso
'

  assert_status 0
  assert_output_shows '対象プロファイル' 'neon-sso'
  assert_aws_not_called 'neon-sso-sso'
}

test_interactive_asks_name_when_no_profile_exists() {
  require_terminal_support

  run_login_on_terminal '
sso
'

  assert_status 0
  assert_not_contains "$OUTPUT" 'プロファイルを選んでください' '端末出力'
  assert_contains "$OUTPUT" 'プロファイル名 (default):' '端末出力'
  assert_output_shows '対象プロファイル' 'default-sso'
}

test_interactive_rejects_an_option_like_profile_name() {
  require_terminal_support

  run_login_on_terminal '--dev
'

  assert_status 2
  assert_contains "$OUTPUT" '有効なプロファイル名を入力してください。' '端末出力'
}

test_interactive_menu_selects_default_with_enter() {
  require_terminal_support
  given_iam_profile alpha mfa_serial=device
  given_iam_profile default mfa_serial=device
  given_mfa_session_profile default-mfa

  run_login_on_terminal '
'

  assert_status 0
  assert_contains "$OUTPUT" 'プロファイルを選んでください' '端末出力'
  assert_not_contains "$OUTPUT" '❯ default-mfa' '端末出力'
  assert_not_contains "$OUTPUT" $'\e[K      default-mfa' '端末出力'
  assert_output_shows '接続プロファイル' 'default-mfa (mfa)'
  assert_not_contains "$OUTPUT" '認証方式を選んでください' '端末出力'
}

test_interactive_menu_moves_with_arrow_keys() {
  require_terminal_support
  given_iam_profile alpha mfa_serial=device
  given_mfa_session_profile alpha-mfa
  given_sso_profile beta-sso

  run_login_on_terminal $'\e[B\n'

  assert_status 0
  assert_output_shows '接続プロファイル' 'beta-sso (sso)'
}

test_interactive_menu_selects_by_number() {
  require_terminal_support
  given_iam_profile alpha mfa_serial=device
  given_mfa_session_profile alpha-mfa
  given_sso_profile beta-sso

  run_login_on_terminal $'2\n'

  assert_status 0
  assert_output_shows '接続プロファイル' 'beta-sso (sso)'
}

test_interactive_menu_last_entry_asks_for_a_new_name() {
  require_terminal_support
  given_sso_profile beta-sso

  run_login_on_terminal $'\e[B\nneon\nsso\n'

  assert_status 0
  assert_contains "$OUTPUT" 'プロファイル名 (default):' '端末出力'
  assert_aws_called 'configure sso --profile neon-sso'
}

test_interactive_menu_selects_a_method_with_a_hotkey() {
  require_terminal_support
  given_profile dev region=ap-northeast-1

  run_login_on_terminal 'm
' --profile dev

  assert_status 2
  assert_contains "$OUTPUT" '認証方式を選んでください' '端末出力'
  assert_contains "$OUTPUT" '登録済み MFA デバイスの ARN / シリアル番号' '端末出力'
  assert_aws_not_called 'configure sso'
}

test_interactive_menu_aborts_with_q() {
  require_terminal_support

  run_login_on_terminal 'neon
q'

  assert_status 2
  assert_contains "$OUTPUT" '認証方式の選択が中断されました。' '端末出力'
}

test_interactive_appends_sso_suffix_to_a_known_profile() {
  require_terminal_support
  given_profile dev region=ap-northeast-1

  given_expired_credentials

  run_login_on_terminal 'sso
' --profile dev

  assert_status 0
  assert_aws_called 'configure sso --profile dev-sso'
  assert_aws_called 'sso login --profile dev-sso'
}

test_interactive_refuses_an_sso_target_used_by_another_method() {
  require_terminal_support
  given_profile dev region=ap-northeast-1
  given_iam_profile dev-sso mfa_serial=device

  run_login_on_terminal 'sso
' --profile dev

  assert_status 2
  assert_contains "$OUTPUT" '保存先 dev-sso は他の認証方式で使用中です。' '端末出力'
}

test_interactive_runs_the_access_key_wizard_and_asks_for_a_device() {
  require_terminal_support
  given_profile dev region=ap-northeast-1

  run_login_on_terminal 'mfa
arn:aws:iam::123456789012:mfa/device
' --profile dev

  assert_status 0
  assert_aws_called 'configure --profile dev'
  assert_aws_called 'configure set mfa_serial arn:aws:iam::123456789012:mfa/device --profile dev'
  assert_profile_value dev mfa_serial arn:aws:iam::123456789012:mfa/device
  assert_aws_called 'configure mfa-login --profile dev '
}

test_interactive_requires_a_device_value() {
  require_terminal_support
  given_iam_profile dev

  run_login_on_terminal '
' mfa --profile dev

  assert_status 2
  assert_contains "$OUTPUT" 'MFA デバイスが必要です。' '端末出力'
}

#!/usr/bin/env bash
#
# スクリプト自体の静的チェック。

# チェック対象のシェルスクリプトを列挙する。
project_scripts() {
  printf '%s\n' \
    "$ROOT/bin/aws-login" \
    "$TESTS_DIR/run.sh" \
    "$TESTS_DIR/bin/aws" \
    "$TESTS_DIR/lib/helpers.sh" \
    "$TESTS_DIR/lib/run_case.sh"
  find "$TESTS_DIR/cases" -name '*_test.sh'
}

test_lint_syntax_is_valid() {
  local script
  while read -r script; do
    bash -n "$script" || report_failure "構文エラー: $script"
  done < <(project_scripts)
}

test_lint_scripts_are_executable() {
  local script
  for script in "$ROOT/bin/aws-login" "$TESTS_DIR/bin/aws"; do
    [[ -x "$script" ]] || report_failure "実行権限がありません: $script"
  done
}

test_lint_shellcheck_reports_nothing() {
  command -v shellcheck > /dev/null || skip_test 'shellcheck がインストールされていません'

  # 1 回で全ファイルを見る。1 ファイルずつ呼ぶと report_failure の return 1 で
  # set -e が働き、最初の 1 ファイルより後ろの指摘が隠れる。
  local script
  local -a scripts=()
  while read -r script; do
    scripts+=("$script")
  done < <(project_scripts)

  shellcheck --shell=bash --exclude=SC1090,SC1091 "${scripts[@]}" ||
    report_failure 'shellcheck の指摘があります'
}

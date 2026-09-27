#!/usr/bin/env bash
#
# テストランナー。tests/cases/*_test.sh の test_ で始まる関数をすべて実行する。
#
#   bash tests/run.sh          すべて実行
#   bash tests/run.sh mfa      名前に mfa を含むテストだけ実行
set -uo pipefail

TESTS_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
SKIP_STATUS=99
filter=${1:-}

passed=0
failed=0
skipped=0
failed_names=()

for case_file in "$TESTS_DIR"/cases/*_test.sh; do
  header_shown=0

  while read -r name; do
    [[ -z "$filter" || "$name" == *"$filter"* ]] || continue

    if (( header_shown == 0 )); then
      printf '\n%s\n' "$(basename "$case_file" .sh)"
      header_shown=1
    fi

    output=$(bash "$TESTS_DIR/lib/run_case.sh" "$case_file" "$name" 2>&1)
    status=$?

    case "$status" in
      0)
        printf '  ok   %s\n' "${name#test_}"
        (( ++passed ))
        ;;
      "$SKIP_STATUS")
        printf '  skip %s\n' "${name#test_}"
        [[ -z "$output" ]] || printf '%s\n' "$output"
        (( ++skipped ))
        ;;
      *)
        printf '  NG   %s\n' "${name#test_}"
        [[ -z "$output" ]] || printf '%s\n' "$output"
        failed_names+=("$name")
        (( ++failed ))
        ;;
    esac
  done < <(grep -oE '^test_[A-Za-z0-9_]+' "$case_file")
done

printf '\n成功 %d / 失敗 %d / スキップ %d\n' "$passed" "$failed" "$skipped"

if (( failed )); then
  printf '失敗したテスト:\n'
  printf '  %s\n' "${failed_names[@]}"
  exit 1
fi

if (( passed == 0 )); then
  printf '実行されたテストがありません。\n' >&2
  exit 1
fi

#!/usr/bin/env bash
#
# テスト 1 件を専用のプロセスで実行する。tests/run.sh から呼ばれる。
# 使い方: run_case.sh <ケースファイル> <テスト関数名>
#
# 独立したプロセスにすることで、set -e を効かせたまま結果を集計できる。
set -euo pipefail

TESTS_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# ROOT と ORIGINAL_PATH は、この後 source する helpers.sh とケースファイルが使う。
# source 先は静的に追えないため未使用に見える（SC1090/SC1091 を除外しているのと同じ理由）。
# shellcheck disable=SC2034
ROOT=$(cd -- "$TESTS_DIR/.." && pwd)
# shellcheck disable=SC2034
ORIGINAL_PATH=$PATH

# テストを飛ばすときの終了コード。tests/run.sh と揃える。
SKIP_STATUS=99

skip_test() {
  printf '    %s\n' "$*" >&2
  exit "$SKIP_STATUS"
}

# shellcheck source=helpers.sh
source "$TESTS_DIR/lib/helpers.sh"
# shellcheck source=/dev/null
source "$1"

trap teardown_workspace EXIT
setup_workspace
"$2"

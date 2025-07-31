#!/usr/bin/env bash
# Usage: run_clang_tidy <OUTPUT> <CONFIG> [ARGS...]
set -ue

CLANG_TIDY_BIN=$1
shift

OUTPUT=$1
shift

CONFIG=$1
shift

# clang-tidy doesn't create a patchfile if there are no errors.
# make sure the output exists, and empty if there are no errors,
# so the build system will not be confused.
touch $OUTPUT
truncate -s 0 $OUTPUT

# Print output on failure only
logfile="$(mktemp)"

# Prepend a flag-based disabling of a check that has a serious bug in
# clang-tidy 16 when used with C++20. Bazel always violates this check and the
# warning is typically disabled, but that warning disablement doesn't work
# correctly in this circumstance and so we need to disable it at the clang-tidy
# level both as a check and from `warnings-as-errors` to avoid it getting
# re-promoted to an error. See the clang-tidy bug here for details:
# https://github.com/llvm/llvm-project/issues/61969
set -- \
  --checks=-clang-diagnostic-builtin-macro-redefined \
  --warnings-as-errors=-clang-diagnostic-builtin-macro-redefined \
   "$@"

if {
  "${CLANG_TIDY_BIN}" --config-file=$CONFIG --quiet --verify-config &&
  "${CLANG_TIDY_BIN}" --config-file=$CONFIG "$@"
} >"$logfile" 2>&1; then
    # Success - just remove the logfile
    rm -f "$logfile"
else
    # Failure - print the log and exit with error
    cat "$logfile" 1>&2
    rm -f "$logfile"
    exit 1
fi

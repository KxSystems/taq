#!/usr/bin/env bash
# shellcheck shell=bash
# SED_INPLACE, DATEARRAY, LETTERS and LETTERARRAY are consumed by the scripts
# that source this file, so they read as "unused" here.
# shellcheck disable=SC2034

script_dir=$(dirname "${BASH_SOURCE[0]}")
# shellcheck source=util.sh
source "${script_dir}/util.sh"

# BSD sed (macOS) requires an explicit empty string after -i; GNU sed does not accept it as a separate arg
if [[ "$(uname -s)" == "Darwin" ]]; then
    SED_INPLACE=(sed -i '')
else
    SED_INPLACE=(sed -i)
fi

# Default values for optional arguments
CSVDIR=""
DATES_RAW=""
SIZE="full"

usage() {
    echo "Usage: $0 --csvdir <dir> --dates <date1,date2,...> [--size small|medium|large|full]"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --csvdir|-c)  CSVDIR="$2";    shift 2 ;;
        --dates|-d)   DATES_RAW="$2"; shift 2 ;;
        --size|-s)    SIZE="$2";      shift 2 ;;
        *) echo "Unknown option: $1"; usage ;;
    esac
done

[[ -z "$CSVDIR" ]]    && { echo "Error: --csvdir is required"; usage; }
[[ -z "$DATES_RAW" ]] && { echo "Error: --dates is required";  usage; }

case "$SIZE" in
    small|medium|large|full) ;;
    *) echo "Error: --size must be one of: small, medium, large, full"; usage ;;
esac

IFS=',' read -r -a DATEARRAY <<< "$DATES_RAW"


LETTERS=$(get_letters "$SIZE")

# LETTERS is a "<start>-<end>" range, e.g. "A-Z". Expand it to an array of
# single characters without eval by walking the character codes.
IFS='-' read -r start_letter end_letter <<< "$LETTERS"
LETTERARRAY=()
for ((code = $(printf '%d' "'${start_letter}"); code <= $(printf '%d' "'${end_letter}"); code++)); do
    printf -v letter '%b' "$(printf '\\%03o' "$code")"
    LETTERARRAY+=("$letter")
done
#!/usr/bin/env bash

# Extract a small test dataset from a directory of NYSE TAQ PSV files.
# Instruments are selected from the trade file: every Symbol with fewer than
# MAXTRADES entries whose first character falls within --letters is kept, and
# the trade, master and BBO files are filtered down to those symbols. BBO
# files are split per letter, so files outside --letters are never parsed.

set -euo pipefail

script_dir=$(dirname "${BASH_SOURCE[0]}")
# shellcheck source=../scripts/util.sh
source "${script_dir}/../scripts/util.sh"

# Symbols with at least this many trades are dropped from the test dataset.
MAXTRADES="${MAXTRADES:-7}"

PSVDIR=""
PSVDIRTEST=""
LETTERS="A-Z"
DATE=""

usage() {
    echo "Usage: $0 --psvdir <dir> --psvdirtest <dir> [--letters <first>-<last>, e.g. X-Z] [--date <yyyymmdd>]"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --psvdir|-i)     PSVDIR="$2";     shift 2 ;;
        --psvdirtest|-o) PSVDIRTEST="$2"; shift 2 ;;
        --letters|-l)    LETTERS="$2";    shift 2 ;;
        --date|-d)       DATE="$2";       shift 2 ;;
        *) echo "Unknown option: $1"; usage ;;
    esac
done

[[ -z "$PSVDIR" ]]     && { echo "Error: --psvdir is required"; usage; }
[[ -z "$PSVDIRTEST" ]] && { echo "Error: --psvdirtest is required"; usage; }
[[ -d "$PSVDIR" ]] || die "Input directory not found: '$PSVDIR'"
[[ -n "$DATE" ]] && check_date "$DATE"
[[ "$LETTERS" =~ ^[A-Z]-[A-Z]$ ]] || die "--letters must be a range like X-Z. Got: '$LETTERS'"

IFS='-' read -r start_letter end_letter <<< "$LETTERS"
(( $(printf '%d' "'$start_letter") <= $(printf '%d' "'$end_letter") )) \
    || die "--letters range is reversed: '$LETTERS'"

require_commands gawk

# Byte-wise processing is all we need and is much faster than UTF-8 aware.
export LC_ALL=C

mkdir -p "$PSVDIRTEST"

symfile=$(mktemp)
trap 'rm -f "$symfile"' EXIT

# Keep the header plus every row whose Symbol column is listed in symfile.
filter_by_symbols() {
    local infile="$1" symcol="$2" outfile="$3"
    gawk -F'|' -v symcol="$symcol" '
        ARGIND == 1 { sel[$0]; next }
        FNR == 1 || ($symcol in sel)
    ' "$symfile" "$infile" > "$outfile"
}

# The directory may hold PSV files for multiple dates; without --date every
# date that has a trade file is processed.
shopt -s nullglob
# With --date the pattern is a literal filename that nullglob leaves in place
# even when missing, so check the first entry's existence explicitly.
tradefiles=("${PSVDIR}"/EQY_US_ALL_TRADE_${DATE:-*}.psv)
[[ ${#tradefiles[@]} -gt 0 && -f "${tradefiles[0]}" ]] \
    || die "No EQY_US_ALL_TRADE_${DATE:-*}.psv file found in '$PSVDIR'"

for tradefile in "${tradefiles[@]}"; do
    fname=$(basename "$tradefile")
    date="${fname#EQY_US_ALL_TRADE_}"
    date="${date%.psv}"
    check_date "$date"

    echo "Selecting symbols in range ${LETTERS} with fewer than ${MAXTRADES} trades from ${fname}"
    # First pass counts trades per Symbol (column 3) for the requested
    # letters, second pass writes the filtered trade file. The selected
    # symbols land in symfile for filtering the master and BBO files.
    gawk -F'|' -v pat="^[${LETTERS}]" -v max="$MAXTRADES" -v symfile="$symfile" '
        NR == FNR { if (FNR > 1 && substr($3, 1, 1) ~ pat) cnt[$3]++; next }
        FNR == 1  { print; next }
        ($3 in cnt) && cnt[$3] < max { sel[$3]; print }
        END { for (s in sel) print s > symfile }
    ' "$tradefile" "$tradefile" > "${PSVDIRTEST}/${fname}"
    echo "Kept $(wc -l < "$symfile") symbols"

    masterfile="EQY_US_ALL_REF_MASTER_${date}.psv"
    if [[ -f "${PSVDIR}/${masterfile}" ]]; then
        echo "Filtering ${masterfile}"
        # In the master file the Symbol is the first column.
        filter_by_symbols "${PSVDIR}/${masterfile}" 1 "${PSVDIRTEST}/${masterfile}"
    else
        echo "WARNING: ${masterfile} not found in '$PSVDIR', skipping" >&2
    fi

    for ((code = $(printf '%d' "'${start_letter}"); code <= $(printf '%d' "'${end_letter}"); code++)); do
        letter=$(printf "\\$(printf '%03o' "$code")")
        quotefile="SPLITS_US_ALL_BBO_${letter}_${date}.psv"
        if [[ -f "${PSVDIR}/${quotefile}" ]]; then
            echo "Filtering ${quotefile}"
            filter_by_symbols "${PSVDIR}/${quotefile}" 3 "${PSVDIRTEST}/${quotefile}"
        else
            echo "WARNING: ${quotefile} not found in '$PSVDIR', skipping" >&2
        fi
    done
done

echo "Test PSV files written to '$PSVDIRTEST'"

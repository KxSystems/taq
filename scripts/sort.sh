#!/usr/bin/env bash

set -euo pipefail

script_dir=$(dirname "${BASH_SOURCE[0]}")
# shellcheck source=common.sh
source "${script_dir}/common.sh"

function sort_by_time () {
    local date=$1
    local f

    f="${CSVDIR}/$(getFilename "EQY" "TRADE" "${date}")"
    f="${f%.*}.psv"
    echo "Sorting trade file by time: ${f}"
    { head -1 "$f"; tail -n +2 "$f" | sort -t'|' -k1,1; } > "${f}.tmp" && mv "${f}.tmp" "$f"

    local merged="${CSVDIR}/EQY_US_ALL_BBO_${date}.psv"
    head -n 1 $(ls ${CSVDIR}/SPLITS_US_ALL_BBO_[$LETTERS]_${date}.psv | head -n 1) > "$merged"
    local tmpdir
    tmpdir=$(mktemp -d "${CSVDIR}/.tmp_XXXXXX")
    for f in ${CSVDIR}/SPLITS_US_ALL_BBO_[$LETTERS]_${date}.psv; do
        echo "Sorting quote file by time: ${f}"
        tail -n +2 "$f" | sort -t'|' -k1,1 > "${tmpdir}/$(basename "$f")"
        rm $f
    done

    echo "Merging quote files into: ${merged}"
    sort -m -t'|' -k1,1 "${tmpdir}"/* >> "$merged"
    rm -rf "$tmpdir"
}

echo "NYSE TAQ CSV resort by time started."
readonly start=$(date +%s)

for date in "${DATEARRAY[@]}"; do
    sort_by_time "$date"
done

readonly end=$(date +%s)
readonly duration=$((end - start))
echo "TAQ data resort by time completed in ${duration} seconds."
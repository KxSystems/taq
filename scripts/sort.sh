#!/usr/bin/env bash

set -euo pipefail

script_dir=$(dirname "${BASH_SOURCE[0]}")
# shellcheck source=common.sh
source "${script_dir}/common.sh"

sort_by_time() {
    local date="$1"
    local f merged tmpdir

    f="${CSVDIR}/$(get_filename "EQY" "TRADE" "${date}")"
    f="${f%.*}.psv"
    echo "Sorting trade file by time: ${f}"
    { head -1 "$f"; tail -n +2 "$f" | sort -t'|' -k1,1; } > "${f}.tmp" && mv "${f}.tmp" "$f"

    merged="${CSVDIR}/EQY_US_ALL_BBO_${date}.psv"

    # Collect the per-letter quote files via a glob (no `ls` parsing).
    # [$LETTERS] is an intentional glob character class (e.g. [A-Z]), so it
    # must stay unquoted; CSVDIR and date are quoted.
    # shellcheck disable=SC2206
    local quote_files=("${CSVDIR}"/SPLITS_US_ALL_BBO_[$LETTERS]_"${date}".psv)
    if [[ ! -f "${quote_files[0]}" ]]; then
        die "No quote files found for date ${date} in ${CSVDIR}" 1
    fi

    head -n 1 "${quote_files[0]}" > "$merged"
    tmpdir=$(mktemp -d "${CSVDIR}/.tmp_XXXXXX")
    for f in "${quote_files[@]}"; do
        echo "Sorting quote file by time: ${f}"
        tail -n +2 "$f" | sort -t'|' -k1,1 > "${tmpdir}/$(basename "$f")"
        rm "$f"
    done

    echo "Merging quote files into: ${merged}"
    sort -m -t'|' -k1,1 "${tmpdir}"/* >> "$merged"
    rm -rf "$tmpdir"
}

echo "NYSE TAQ CSV resort by time started."
start=$(date +%s)
readonly start

for date in "${DATEARRAY[@]}"; do
    check_date "${date}"
    sort_by_time "$date"
done

end=$(date +%s)
readonly end
readonly duration=$((end - start))
echo "TAQ data resort by time completed in ${duration} seconds."
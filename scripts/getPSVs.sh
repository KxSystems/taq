#!/usr/bin/env bash

# '$d' below is a sed script (delete the last line), not a shell variable, so
# it is intentionally single-quoted.
# shellcheck disable=SC2016

set -euo pipefail

script_dir=$(dirname "${BASH_SOURCE[0]}")
# shellcheck source=common.sh
source "${script_dir}/common.sh"

readonly URLPREFIX="https://ftp.nyse.com/Historical%20Data%20Samples/DAILY%20TAQ/"

# gawk is required for the in-place letter filtering (`gawk -i inplace`); the
# default macOS awk does not support it. curl/gunzip are used for download.
require_commands curl gunzip gawk

get_CSVs() {
  local date="$1"
  local letter qfname tfname mfname letters
  local gunzip_pids=()

  echo "Fetching gzipped CSV files for date ${date}"
  mkdir -p "${CSVDIR}"
  pushd "${CSVDIR}" > /dev/null

  for letter in "${LETTERARRAY[@]}"; do
    qfname=$(get_filename "SPLITS" "BBO_${letter}" "${date}")
    if [[ -f "${qfname%.*}" || -f "${qfname%.*}.psv" ]]; then
      echo "${qfname} was already downloaded and unzipped. Skipping download."
    else
      curl -C - -O "${URLPREFIX}${qfname}"
      echo "Unzipping downloaded file in the background"
      gunzip "${qfname}" &
      gunzip_pids+=("$!")
    fi
  done

  tfname=$(get_filename "EQY" "TRADE" "${date}")
  if [[ -f "${tfname%.*}" || -f "${tfname%.*}.psv" ]]; then
    echo "${tfname} was already downloaded and unzipped. Skipping download."
  else
    curl -C - -O "${URLPREFIX}${tfname}"
    echo "Unzipping downloaded file"
    gunzip "${tfname}"
  fi

  mfname=$(get_filename "EQY" "REF_MASTER" "${date}")
  if [[ -f "${mfname%.*}" || -f "${mfname%.*}.psv" ]]; then
    echo "${mfname} was already downloaded and unzipped. Skipping download."
  else
    curl -C - -O "${URLPREFIX}${mfname}"
    echo "Unzipping downloaded file"
    gunzip "${mfname}"
  fi

  # A bare `wait` always returns 0, so a failed background gunzip would slip
  # past `set -e`; wait on each PID individually and abort on any failure.
  local pid
  for pid in "${gunzip_pids[@]}"; do
    wait "${pid}" || die "A background gunzip failed while fetching ${date}" 1
  done

  # TODO: add check if last line starts with 'END'
  # Only files that were (re)downloaded exist unzipped without the .psv
  # extension; skip any that already have a .psv from a previous run.
  echo "Removing last lines and adding proper extension"
  [[ -f "${mfname%.*}" ]] && "${SED_INPLACE[@]}" '$d' "${mfname%.*}" && mv "${mfname%.*}" "${mfname%.*}.psv"
  [[ -f "${tfname%.*}" ]] && "${SED_INPLACE[@]}" '$d' "${tfname%.*}" && mv "${tfname%.*}" "${tfname%.*}.psv"
  for letter in "${LETTERARRAY[@]}"; do
    qfname=$(get_filename "SPLITS" "BBO_${letter}" "${date}")
    [[ -f "${qfname%.*}" ]] && "${SED_INPLACE[@]}" '$d' "${qfname%.*}" && mv "${qfname%.*}" "${qfname%.*}.psv"
  done

  letters=$(IFS=''; printf '%s' "${LETTERARRAY[@]}")
  if [[ ${#letters} -lt 26 ]]; then
    echo "Filtering master file for letters ${letters}"
    # in master file the Symbol is the first column
    gawk -i inplace -F'|' -v pat="^[$letters]" 'NR==1 || substr($1,1,1) ~ pat' "${mfname%.*}.psv"
    # in trade file the Symbol is the third column
    echo "Filtering trade file for letters ${letters}"
    gawk -i inplace -F'|' -v pat="^[$letters]" 'NR==1 || substr($3,1,1) ~ pat' "${tfname%.*}.psv"
  fi

  popd > /dev/null
}

echo "NYSE TAQ CSV capture started."
start=$(date +%s)
readonly start

for date in "${DATEARRAY[@]}"; do
  check_date "${date}"
  get_CSVs "${date}"
done

end=$(date +%s)
readonly end
readonly duration=$((end - start))
echo "TAQ data capture completed in ${duration} seconds."
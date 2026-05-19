#!/usr/bin/env bash

set -euo pipefail

script_dir=$(dirname "${BASH_SOURCE[0]}")
# shellcheck source=common.sh
source "${script_dir}/common.sh"

readonly URLPREFIX="https://ftp.nyse.com/Historical%20Data%20Samples/DAILY%20TAQ/"

function get_CSVs () {
  local date=$1
  local letterarray=$2

  echo "Fetching gzipped CSV files for date ${date}"
  mkdir -p ${CSVDIR}
  pushd ${CSVDIR}

  for letter in ${LETTERARRAY[@]}; do
    qfname=$(getFilename "SPLITS" "BBO_${letter}" ${date})
    if [[ -f ${qfname%.*} ]]; then
      echo "${qfname} was already downloaded and unzipped. Skipping download."
    else
      curl -C - -O "${URLPREFIX}${qfname}"
      echo "Unzipping downloaded file in the background"
      gunzip "${qfname}" &
    fi
  done

  local tfname=$(getFilename "EQY" "TRADE" ${date})
  if [[ -f ${tfname%.*} ]]; then
    echo "${tfname} was already downloaded and unzipped. Skipping download."
  else
    curl -C - -O "${URLPREFIX}${tfname}"
    echo "Unzipping downloaded file"
    gunzip "${tfname}"
  fi

  local mfname=$(getFilename "EQY" "REF_MASTER" ${date})
  if [[ -f ${mfname%.*} ]]; then
    echo "${mfname} was already downloaded and unzipped. Skipping download."
  else
    curl -C - -O "${URLPREFIX}${mfname}"
    echo "Unzipping downloaded file"
    gunzip "${mfname}"
  fi

  wait

  # TODO: add check if last line starts with 'END'
  echo "Removing last lines and adding proper extension"
  "${SED_INPLACE[@]}" '$d' ${mfname%.*} && mv ${mfname%.*} ${mfname%.*}.psv
  "${SED_INPLACE[@]}" '$d' ${tfname%.*} && mv ${tfname%.*} ${tfname%.*}.psv
  for letter in ${LETTERARRAY[@]}; do
    qfname=$(getFilename "SPLITS" "BBO_${letter}" ${date})
    "${SED_INPLACE[@]}" '$d' ${qfname%.*} && mv ${qfname%.*} ${qfname%.*}.psv
  done

  local letters=$(IFS=''; printf '%s' "${LETTERARRAY[@]}")
  if [[ ${#letters} -lt 26 ]]; then
    echo "Filtering master file for letters ${letters}"
    # in master file the Symbol is the first column
    gawk -i inplace -F'|' -v pat="^[$letters]" 'NR==1 || substr($1,1,1) ~ pat' "${mfname%.*}.psv"
    # in trade file the Symbol is the third column
    echo "Filtering trade file for letters ${letters}"
    gawk -i inplace -F'|' -v pat="^[$letters]" 'NR==1 || substr($3,1,1) ~ pat' "${tfname%.*}.psv"
  fi

  popd
}

echo "NYSE TAQ CSV capture started."
readonly start=$(date +%s)

for date in ${DATEARRAY[@]}; do
  get_CSVs $date $LETTERARRAY
done

readonly end=$(date +%s)
readonly duration=$((end - start))
echo "TAQ data capture completed in ${duration} seconds."
#!/usr/bin/env bash

set -euo pipefail

script_dir=$(dirname "${BASH_SOURCE[0]}")

CSVDIR="$1"
IFS=',' read -r -a DATEARRAY <<< "$2"
SIZE="${SIZE:-full}"

readonly URLPREFIX="https://ftp.nyse.com/Historical%20Data%20Samples/DAILY%20TAQ/"

function get_letters () {
    SIZE=$1

    readonly VALID_SIZES=("full" "large" "medium" "small")
    : "${SIZE:?Error: SIZE must be set to 'full', 'large', 'medium', or 'small'}"

    if [[ ! " ${VALID_SIZES[*]} " =~ " ${SIZE} " ]]; then
        echo "Error: Unknown SIZE: $SIZE. Valid options are: ${VALID_SIZES[*]}"
        exit 1
    fi

    case "$SIZE" in
      "full")   LETTERS='A-Z' ;;
      "large")  LETTERS='A-H' ;;
      "medium") LETTERS='I-I' ;;
      "small")  LETTERS='Z-Z' ;;
    esac

    echo ${LETTERS}
}


function getFilename() {
    local type=$1 letter=$2 date=$3
    echo "${type}_US_ALL_${letter}_${date}.gz"
}

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
  head -n -1 ${tfname%.*} > ${tfname%.*}.psv
  rm ${tfname%.*}
  head -n -1 ${mfname%.*} > ${mfname%.*}.psv
  rm ${mfname%.*}
  for letter in ${LETTERARRAY[@]}; do
    qfname=$(getFilename "SPLITS" "BBO_${letter}" ${date})
    head -n -1 ${qfname%.*} > ${qfname%.*}.psv
    rm ${qfname%.*}
  done

  popd
}

echo "NYSE TAQ CSV capture started."
readonly start=$(date +%s)

LETTERS=$(get_letters $SIZE)
LETTERARRAY=($(eval echo {${LETTERS:0:1}..${LETTERS:2:1}}))

for date in ${DATEARRAY[@]}; do
  get_CSVs $date $LETTERARRAY
done

readonly end=$(date +%s)
readonly duration=$((end - start))
echo "TAQ data capture completed in ${duration} seconds."
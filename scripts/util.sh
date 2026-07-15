#!/usr/bin/env bash
# shellcheck shell=bash

die() {
  local msg="$1"
  local code="${2:-1}"
  echo "ERROR: $msg" >&2
  # Return when sourced, exit when executed directly.
  # shellcheck disable=SC2317
  return "$code" 2>/dev/null || exit "$code"
}

get_letters() {
  local size="$1"
  local -A letters_by_size=(
    [full]='A-Z'
    [xlarge]='I-Z'
    [large]='P-Z'
    [medium]='T-Z'
    [small]='X-Z'
    [tiny]='Z-Z'
  )

  if [[ ! -v letters_by_size[$size] ]]; then
    # die returns (rather than exits) when sourced, so propagate the failure
    # out of get_letters explicitly for callers that check its status.
    die "Unknown SIZE: '$size'. Valid options are: ${!letters_by_size[*]}" 1
    return 1
  fi

  echo "${letters_by_size[$size]}"
}

check_date() {
  local date="$1"
  if ! [[ "$date" =~ ^[0-9]{8}$ ]]; then
    die "DATE must be in YYYYMMDD format. Got: '$date'" 1
  fi
}

get_filename() {
  local type="$1" letter="$2" date="$3"
  echo "${type}_US_ALL_${letter}_${date}.gz"
}

# Abort unless every named command is available on PATH.
require_commands() {
  local cmd missing=()
  for cmd in "$@"; do
    command -v "$cmd" > /dev/null 2>&1 || missing+=("$cmd")
  done
  if ((${#missing[@]} > 0)); then
    die "Required command(s) not found on PATH: ${missing[*]}" 1
  fi
}

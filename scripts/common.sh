function get_letters () {
    local size=$1
    case "$size" in
      "full")   echo 'A-Z' ;;
      "large")  echo 'A-H' ;;
      "medium") echo 'I-I' ;;
      "small")  echo 'Z-Z' ;;
    esac
}

function getFilename() {
    local type=$1 letter=$2 date=$3
    echo "${type}_US_ALL_${letter}_${date}.gz"
}

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
LETTERARRAY=($(eval echo "{${LETTERS:0:1}..${LETTERS:2:1}}"))
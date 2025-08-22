#!/usr/bin/env bash

ZIPLINE_AUTH_TOKEN_FILE=""
ZIPLINE_URL=""
ZIPLINE_USE_ORIGINAL_NAME=true
FLAMESHOT_SAVE_PATH="/tmp"

show_help() {
  echo "Usage: $0 [options]"
  echo ""
  echo "Options:"
  echo "  -p, --path <path>                Set the Flameshot save path (default: /tmp)"
  echo "  -m, --mode <mode>                Set Flameshot mode (e.g., gui, full, screen)"
  echo "  -u, --url <url>                  Set the Zipline upload URL"
  echo "  -t, --token <token_file>         Set the Zipline auth token file"
  echo "  -o, --original-name <true|false> Use original file name for upload (default: true)"
  echo "  -h, --help                       Show this help message"
  echo ""
  echo "This script takes a screenshot with Flameshot, uploads it to Zipline,"
  echo "and copies the resulting URL to the clipboard."
}

generate_name() {
  date +%Y-%m-%d_%H-%M-%S
}

main() {
  while [[ "$#" -gt 0 ]]; do
    case $1 in
      -p|--path) FLAMESHOT_SAVE_PATH="$2"; shift ;;
      -m|--mode) FLAMESHOT_MODE="$2"; shift ;;
      -u|--url) ZIPLINE_URL="$2"; shift ;;
      -t|--token) ZIPLINE_AUTH_TOKEN_FILE="$2"; shift ;;
      -o|--original-name) ZIPLINE_USE_ORIGINAL_NAME="$2"; shift ;;
      -h|--help) show_help; exit 0 ;;
      *) echo "Unknown parameter passed: $*"; show_help; exit 1 ;;
    esac
    shift
  done

  name=$(generate_name)

  if [ "${FLAMESHOT_MODE}" == "gui" ]; then
    FLAMESHOT_CMD="flameshot gui -s -p ${FLAMESHOT_SAVE_PATH}/${name}.png"
  else
    FLAMESHOT_CMD="flameshot ${FLAMESHOT_MODE} -p ${FLAMESHOT_SAVE_PATH}/${name}.png"
  fi

  if ${FLAMESHOT_CMD}; then
    curl -SsL -H "authorization: $(cat "${ZIPLINE_AUTH_TOKEN_FILE}")" \
      -F "file=@${FLAMESHOT_SAVE_PATH}/${name}.png" \
      -H 'content-type: multipart/form-data' \
      -H "x-zipline-original-name: ${ZIPLINE_USE_ORIGINAL_NAME}" \
      "${ZIPLINE_URL}/api/upload" | \
    jq -r .files[0].url | tr -d '\n' | wl-copy
  fi
}

main "$@"
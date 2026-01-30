#!/bin/bash
set -euo pipefail
shopt -s nullglob

CIRCUIT_NAME="${1:-SustainabilityCheck}"
INPUT_GLOB="${2:-inputs/${CIRCUIT_NAME}_input_*.json}"
REPORT_PATH="${3:-reports/prove_many.csv}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

mkdir -p "$(dirname "$REPORT_PATH")"
echo "id,expected_valid,prove_success,time_ms,error" > "$REPORT_PATH"

inputs=( $INPUT_GLOB )
if [ ${#inputs[@]} -eq 0 ]; then
  echo "No inputs found for pattern: $INPUT_GLOB"
  exit 1
fi

for input in "${inputs[@]}"; do
  base="$(basename "$input" .json)"
  if [[ "$base" == *"_valid" ]]; then
  expected_valid=1
  elif [[ "$base" == *"_invalid" ]]; then
  expected_valid=0
  else
  expected_valid=""
  fi

  start_ms=$(date +%s%3N)
  err_file="$(mktemp)"
  if ./scripts/prove.sh "$CIRCUIT_NAME" "$base" "$input" >/dev/null 2>"$err_file"; then
  prove_success=1
  err_msg=""
  else
  prove_success=0
  err_msg="$(tail -n 3 "$err_file" | tr '\n' ' ' | sed 's/"/""/g')"
  err_msg="$(echo "$err_msg" | sed 's/[[:space:]]\\+/ /g' | sed 's/^ //;s/ $//')"
  fi
  rm -f "$err_file"
  end_ms=$(date +%s%3N)
  time_ms=$((end_ms - start_ms))

  echo "${base},${expected_valid},${prove_success},${time_ms},\"${err_msg}\"" >> "$REPORT_PATH"
done

echo "Report written to ${REPORT_PATH}"

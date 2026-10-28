#!/bin/sh
# Fixed profile: 10 packets per direction / 10 diagnostic cycles per GPIO.
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
exec sh "$SCRIPT_DIR/run_all_parallel_tests.sh" "$@" \
    --iterations 10 --eth-count 10 --rs485-count 10 --dido-count 10 --relay-count 10

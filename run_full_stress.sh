#!/bin/sh
# Fixed profile: 10000 packets per direction / 10000 diagnostic cycles per GPIO.
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
exec sh "$SCRIPT_DIR/run_all_parallel_tests.sh" "$@" \
    --iterations 10000 --eth-count 10000 --rs485-count 10000 --dido-count 10000 --relay-count 10000

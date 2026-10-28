#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
if [ ! -x "$SCRIPT_DIR/ems_test_runner" ]; then
    echo "Error: build/install ems_test_runner next to this script first" >&2
    exit 2
fi
exec "$SCRIPT_DIR/ems_test_runner" "$@"

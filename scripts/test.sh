#!/bin/zsh
# Tests the engine (layouts, editing, rendering, the document format) with the Swift package.
set -e
cd "$(dirname "$0")/.."
swift test --scratch-path build/spm "$@"

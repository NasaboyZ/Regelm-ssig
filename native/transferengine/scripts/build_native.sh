#!/usr/bin/env bash
set -euo pipefail

target="${1:-host}"
output="${2:-../../build/native-transferengine}"
module_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$module_dir"
mkdir -p "$output"

case "$target" in
  host)
    go build -buildmode=c-shared -o "$output/libregelmaessig_transfer.dylib" ./cmd/bridge
    ;;
  android)
    GOOS=android GOARCH=arm64 CGO_ENABLED=1 go build -buildmode=c-shared -o "$output/libregelmaessig_transfer.so" ./cmd/bridge
    ;;
  ios)
    GOOS=ios GOARCH=arm64 CGO_ENABLED=1 go build -buildmode=c-archive -o "$output/libregelmaessig_transfer.a" ./cmd/bridge
    ;;
  *)
    echo "usage: $0 host|android|ios [output-directory]" >&2
    exit 2
    ;;
esac

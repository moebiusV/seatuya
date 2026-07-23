#!/bin/sh
# Fetch dependencies that are not installed system-wide.
# These are cloned into deps/ and built as part of seatuya.
# Nothing here is shipped in the repository.
set -e

DEPS_DIR="$(cd "$(dirname "$0")" && pwd)/deps"
mkdir -p "$DEPS_DIR"

fetch_tuyapp() {
    if [ -f "$DEPS_DIR/tuyapp/src/tuyaAPI.hpp" ]; then
        echo "tuyapp: already present."
    else
        echo "tuyapp: cloning from GitHub..."
        git clone https://github.com/gordonb3/tuyapp.git "$DEPS_DIR/tuyapp"
    fi
}

fetch_libyaml() {
    if pkg-config --exists yaml-0.1 2>/dev/null; then
        echo "libyaml: found system installation, skipping."
        return
    fi
    if [ -f "$DEPS_DIR/libyaml/src/yaml.h" ]; then
        echo "libyaml: already present."
    else
        echo "libyaml: not installed system-wide, cloning from GitHub..."
        git clone --depth 1 https://github.com/yaml/libyaml.git "$DEPS_DIR/libyaml"
    fi
}

fetch_jsoncpp() {
    if pkg-config --exists jsoncpp 2>/dev/null; then
        echo "jsoncpp: found system installation, skipping."
        return
    fi
    if [ -f "$DEPS_DIR/jsoncpp/include/json/json.h" ]; then
        echo "jsoncpp: already present."
    else
        echo "jsoncpp: not installed system-wide, cloning from GitHub..."
        git clone https://github.com/open-source-parsers/jsoncpp.git "$DEPS_DIR/jsoncpp"
    fi
}

fetch_tuyapp
fetch_jsoncpp
fetch_libyaml

echo "Done. Run ./configure to continue."

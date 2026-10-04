#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"

# Compile the unchanged library sources and this tool into one temporary module.
# This gives the tool internal access without adding API or a package product.
mkdir -p .build/readme-images/module-cache
xcrun swiftc -parse-as-library -swift-version 5 -target "$(uname -m)-apple-macosx14.0" \
    -module-cache-path .build/readme-images/module-cache \
    "$@" \
    Sources/DynamicLanding/**/*.swift Scripts/ReadmeImages.swift \
    -o .build/readme-images/generate
.build/readme-images/generate

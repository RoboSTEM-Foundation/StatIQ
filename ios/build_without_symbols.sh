#!/bin/bash

# Build IPA without debug symbols
echo "Building IPA without debug symbols..."

# Set environment variables to disable debug symbols
export DEBUG_INFORMATION_FORMAT=dwarf
export STRIP_SWIFT_SYMBOLS=YES
export STRIP_INSTALLED_PRODUCT=YES

# Build the IPA
flutter build ipa --export-options-plist=ios/ExportOptions.plist

# Remove any remaining debug symbols
echo "Removing any remaining debug symbols..."
find build/ios/archive -name "*.dSYM" -type d -exec rm -rf {} + 2>/dev/null || true
find build/ios/archive -name "*.bcsymbolmap" -type f -delete 2>/dev/null || true

echo "Build complete!" 
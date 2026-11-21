#!/bin/bash
set -e

cd "$(dirname "$0")"

echo "Compiling AutoClicker universal binary..."
clang -O3 -Wall -Wextra -arch arm64 -arch x86_64 \
    -framework ApplicationServices -framework Carbon \
    autoclicker.c -o autoclicker

chmod +x autoclicker
echo "Build complete! Output: autoclicker"
file autoclicker
ls -lh autoclicker

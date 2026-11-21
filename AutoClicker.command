#!/bin/bash
# Double-click this script in Finder to run AutoClicker in a terminal window.
cd "$(dirname "$0")"

# Ensure binary is built
if [ ! -f "./autoclicker" ]; then
    echo "Building autoclicker binary..."
    make
fi

./autoclicker "$@"

echo ""
read -n 1 -s -r -p "Press any key to close this window..."
echo ""

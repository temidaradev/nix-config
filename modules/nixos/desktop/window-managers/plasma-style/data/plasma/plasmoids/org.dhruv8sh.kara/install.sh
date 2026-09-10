#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

PLASMOID_DIR="$HOME/.local/share/plasma/plasmoids/org.dhruv8sh.kara"

if [ -d "$PLASMOID_DIR" ]; then
	echo "Existing plasmoid found. Removing old version..."
	rm -rf "$PLASMOID_DIR"
else
	echo "Plasmoid not found. Ensuring destination directory exists..."
	mkdir -p "$(dirname "$PLASMOID_DIR")"
fi

echo "Installing plasmoid to $PLASMOID_DIR..."
cp -r . "$PLASMOID_DIR"

echo "Restarting Plasma Shell..."
systemctl --user restart plasma-plasmashell

echo "Successfully installed/updated the plasmoid."

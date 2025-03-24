#!/bin/bash

# Kill any running instances of the app
echo "Killing any running instances of App..."
pkill -9 App || true

# Run the app
echo "Starting App..."
swift run 
#!/bin/bash
# Build script for Render deployment

echo "Installing dependencies..."
apt-get update && apt-get install -y libpopt-dev gcc

echo "Compiling puzzle box generator..."
cd generator
gcc -O -o puzzlebox puzzlebox.c -lpopt -lm

echo "Build complete!"
ls -la puzzlebox


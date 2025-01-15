#!/bin/bash
set -e

# Inputs: file1, file2, threshold
FILE1=$1
FILE2=$2
THRESHOLD=$3

if [ ! -f "$FILE1" ]; then
    echo "File not found: $FILE1"
    exit 1
fi

if [ ! -f "$FILE2" ]; then
    echo "File not found: $FILE2"
    exit 1
fi

# Get sizes of files (Linux-compatible)
SIZE1=$(stat --format=%s "$FILE1")
SIZE2=$(stat --format=%s "$FILE2")

# Calculate absolute size difference
SIZE_DIFF=$(( SIZE1 - SIZE2 ))
SIZE_DIFF=${SIZE_DIFF#-} # Convert to absolute value

# Print results
echo "File 1: $FILE1 (Size: $SIZE1 bytes)"
echo "File 2: $FILE2 (Size: $SIZE2 bytes)"
echo "Difference: $SIZE_DIFF bytes"

# Check if the size difference exceeds the threshold
if [ "$SIZE_DIFF" -gt "$THRESHOLD" ]; then
    echo "ERROR: Size difference between $FILE1 and $FILE2 exceeds $THRESHOLD bytes!"
    exit 1
else
    echo "SUCCESS: Size difference between $FILE1 and $FILE2 is within $THRESHOLD bytes."
fi
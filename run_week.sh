#!/bin/sh
if [ "$#" -ne 1 ]; then
    echo "Usage: run_week.sh <week_nr>"
    exit 1
fi
echo $1
zig run "week$1.zig"

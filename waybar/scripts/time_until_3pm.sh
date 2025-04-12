#!/bin/bash

now=$(date +%s)
target=$(date -d "15:00" +%s)

# If it's past 3 PM, set target to tomorrow
if [ "$now" -ge "$target" ]; then
    target=$(date -d "15:00 tomorrow" +%s)
fi

seconds_left=$((target - now))
hours=$((seconds_left / 3600))
minutes=$(((seconds_left % 3600) / 60))

echo "${hours}h ${minutes}m"

#!/bin/bash
PREFIX=$1

# grid_sync
benchmark="grid_sync"
caught=0;
races=$(grep -A1 "Race" "${PREFIX}${benchmark}.raw")
races=$(echo $races | grep -oE "Missing [a-z]+fence")
# Races are caused by missing fence
for i in $races; do
	caught=1;
done

echo ${benchmark} ${caught}

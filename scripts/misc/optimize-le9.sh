#!/bin/sh
totalmem_kb=`LC_ALL=C free|awk '/^Mem:/ {print $2}'`
clean_min_kb=$((totalmem_kb / 20))
alt=6144
if [ $clean_min_kb -gt $alt ]; then clean_min_kb=$alt; fi
clean_low_kb=$((totalmem_kb / 10))
alt=`echo "v=e(l($totalmem_kb)*l(sqrt(2)))*1000;scale=0;v/1" | bc -l`
if [ $clean_low_kb -gt $alt ]; then clean_low_kb=$alt; fi
sysctl -w vm.clean_min_kbytes=$clean_min_kb
sysctl -w vm.clean_low_kbytes=$clean_low_kb


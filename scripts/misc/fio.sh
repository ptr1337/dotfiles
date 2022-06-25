#!/bin/bash
t=60
name=test

for j in randread randwrite read write;do

for bs in 4k 1m;do

fio \
 --name ${name}_${j}_${bs} \
 --eta-newline=5s --rw=${j} --size=5g --io_size=5g --blocksize=${bs} --ioengine=libaio \
 --fsync=1 --iodepth=1 --direct=1 --numjobs=6 \
 --runtime=${t} --group_reporting  --stonewall \
 --fallocate=native \
 --output=${name}_${j}_${bs}.json \
 --output-format=json+

done
done

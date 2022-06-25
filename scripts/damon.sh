#!/usr/bin/env bash

sudo mount -t debugfs none /sys/kernel/debug/


## Does not work with sudo
sudo su

echo 500 > /sys/module/damon_lru_sort/parameters/hot_thres_access_freq
echo 120000000 > /sys/module/damon_lru_sort/parameters/cold_min_age
echo 10 > /sys/module/damon_lru_sort/parameters/quota_ms
echo 1000 > /sys/module/damon_lru_sort/parameters/quota_reset_interval_ms
echo 500 > /sys/module/damon_lru_sort/parameters/wmarks_high
echo 400 > /sys/module/damon_lru_sort/parameters/wmarks_mid
echo 200 > /sys/module/damon_lru_sort/parameters/wmarks_low
echo Y > /sys/module/damon_lru_sort/parameters/enabled

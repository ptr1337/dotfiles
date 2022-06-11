#!/usr/bin/env bash

sudo mount -t debugfs none /sys/kernel/debug/

echo 500 > sudo /sys/module/damon_lru_sort/parameters/hot_thres_access_freq
echo 120000000 > sudo /sys/module/damon_lru_sort/parameters/cold_min_age
echo 10 > sudo /sys/module/damon_lru_sort/parameters/quota_ms
echo 1000 > sudo /sys/module/damon_lru_sort/parameters/quota_reset_interval_ms
echo 500 > sudo /sys/module/damon_lru_sort/parameters/wmarks_high
echo 400 > sudo /sys/module/damon_lru_sort/parameters/wmarks_mid
echo 200 > sudo /sys/module/damon_lru_sort/parameters/wmarks_low
echo Y > sudo /sys/module/damon_lru_sort/parameters/enabled

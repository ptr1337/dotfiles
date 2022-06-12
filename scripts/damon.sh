#!/usr/bin/env bash

sudo mount -t debugfs none /sys/kernel/debug/

sudo echo 500 > /sys/module/damon_lru_sort/parameters/hot_thres_access_freq
sudo echo 120000000 > /sys/module/damon_lru_sort/parameters/cold_min_age
sudo echo 10 > /sys/module/damon_lru_sort/parameters/quota_ms
sudo echo 1000 > /sys/module/damon_lru_sort/parameters/quota_reset_interval_ms
sudo echo 500 > /sys/module/damon_lru_sort/parameters/wmarks_high
sudo echo 400 > /sys/module/damon_lru_sort/parameters/wmarks_mid
sudo echo 200 > /sys/module/damon_lru_sort/parameters/wmarks_low
sudo echo Y > /sys/module/damon_lru_sort/parameters/enabled

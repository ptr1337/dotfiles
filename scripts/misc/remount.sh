#!/bin/bash

sudo mount -o remount,size=25G,noatime /tmp
echo "Done. Please use 'df -h' to make sure folder size is increased."

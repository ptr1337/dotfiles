#!/usr/bin/env bash

files=$(find . -name "PKGBUILD")

for f in $files
do
  d=$(dirname $f)
  cd $d
  git add .
  git commit -S -m "5.18.6-2"
  git push
  cd ..
done

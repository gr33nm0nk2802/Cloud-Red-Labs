#!/bin/bash

mkdir -p dist
rm -f dist/*.zip

for d in src/*/; do
  name=$(basename "$d")
  (cd "$d" && zip -r -q -FS "../../dist/${name}.zip" .)
done

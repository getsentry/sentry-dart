#!/bin/bash

# usage: alignment.sh path to search for *.so files

dir="$1"

RED="\e[31m"
GREEN="\e[32m"
ENDCOLOR="\e[0m"

matches="$(find $dir -name "*.so" -type f)"
IFS=$'\n'
for match in $matches; do
  res="$(objdump -p ${match} | grep LOAD | awk '{ print $NF }' | head -1)"
  if [[ $res =~ "2**14" ]] || [[ $res =~ "2**16" ]]; then
    echo -e "${match}: ${GREEN}ALIGNED${ENDCOLOR} ($res)"
  else
    echo -e "${match}: ${RED}UNALIGNED${ENDCOLOR} ($res)"
  fi
done

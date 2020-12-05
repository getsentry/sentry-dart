#!/bin/sh

set -e
set -x

pub get
dartanalyzer --fatal-infos --fatal-warnings ./
pub run test -p "chrome,vm"
dartfmt -n --set-exit-if-changed ./

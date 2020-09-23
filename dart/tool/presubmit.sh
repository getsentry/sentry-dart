#!/bin/sh

set -e
set -x

pub get
dartanalyzer --fatal-warnings ./
pub run test -p vm -p chrome
dartfmt -n --set-exit-if-changed ./

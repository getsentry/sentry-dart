#!/bin/sh

set -e
set -x

pub get
dartanalyzer --fatal-warnings ./
pub run test --platform vm --platform chrome
dartfmt -n --set-exit-if-changed ./

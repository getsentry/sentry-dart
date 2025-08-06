#!/usr/bin/env bash
set -euo pipefail

targetDir=$(
  cd $(dirname $0)
  pwd
)
[[ "$targetDir" != "" ]] || exit 1

dartCreate() {
  name=${1//-/_}
  dir=$targetDir/$1
  rm -rf $dir
  echo "::group::dart create $1"
  dart create -t console $name
  echo '::endgroup::'
}

dartCreate 'perf_test_console_plain'
dartCreate 'perf_test_console_sentry'

echo '::group::Patch perf_test_console_sentry'
pubspec="$targetDir/perf_test_console_sentry/pubspec_overrides.yaml"
echo "Adding dependencies to $pubspec"
cat <<EOF >>"$pubspec"

dependency_overrides:
  sentry:
    path: ../../packages/dart

EOF

fileToReplace="$targetDir/perf_test_console_sentry/bin/perf_test_console_sentry.dart"
if [[ -f "$fileToReplace" ]]; then
  echo "Replacing $fileToReplace with new content"
  cat <<'NEW_FILE_CONTENT' >"$fileToReplace"
import 'package:perf_test_console_sentry/perf_test_console_sentry.dart' as perf_test_console_sentry;
import 'package:sentry/sentry.dart';

Future<void> main(List<String> arguments) async {
  await Sentry.init((options) {
    options.dsn = 'https://e85b375ffb9f43cf8bdf9787768149e0@o447951.ingest.sentry.io/5428562';
  });

  print('Hello world: ${perf_test_console_sentry.calculate()}!');
}
NEW_FILE_CONTENT
else
  echo "Error: File $fileToReplace not found!"
  exit 1
fi
echo '::endgroup::'

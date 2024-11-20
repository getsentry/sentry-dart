An internal command-line application to validate publish.
We temporarily need to use the `--skip-validation` flag in order to publish with backwards compatible WASM support.
Since we now don't have validations in place, this validation tool will catch unexpected errors that might occur during dry runs.
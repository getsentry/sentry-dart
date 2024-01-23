# New Package Release Checklist

This page serves as a checklist of what to do when releasing a new package for the first time.

## Release Preparation

- [ ] Make sure the project is set up
    - [ ] The package only exports the public API
    - [ ] The package contains an example folder
    - [ ] The package contains a README.md file
        - [ ] CI badges show a status
    - [ ] The package contains a CHANGELOG.md file (symlink to the root changelog)
    - [ ] The package contains a dartdoc_options.yaml file (symlink to the root file)
    - [ ] The package contains a LICENSE (default is `MIT`)
    - [ ] The package contains a pubspec.yaml file
    - [ ] The package contains a analysis_options.yaml file

- [ ] Update the [Flutter example](https://github.com/getsentry/sentry-dart/tree/main/flutter/example) to use your new package if applicable

- [ ] Make sure your new package has a `version.dart` in the `lib/src` folder.
    - This is used to set the version and package in the `Hub`. See this [example](https://github.com/getsentry/sentry-dart/blob/8609bd8dd7ea572e5d241a59643c7570e5621bda/sqflite/lib/src/sentry_database.dart#L69).
    - The version will be updated to the newest version after triggering the release process.

- [ ] Create a new workflow called `your-package-name.yml` for building and testing the package.

- [ ] Excluding `your-package-name.yml`, add the package to the `paths-ignore` section of all package workflow files.
  - For examples see `sqflite.yml`, `dio.yml` etc...
     
- [ ] Add an entry to [diagram.yml](https://github.com/getsentry/sentry-dart/blob/main/.github/workflows/diagrams.yml) for your package. 

- [ ] In the root `.gitignore` file add the package coverage as ignored.

The `analyze` workflow will fail in your PR and in the main branch because the package is not released yet and the `pubspec.yaml` is not 'valid' according to the analyzer.
This is expected - it will succeed after the release.
- [ ] Make sure the analyze workflow doesn't have other failures, only the one mentioned above.

- [ ] **Very important**: add your package to `scripts/bump-version.sh`.

## Doing the Release

Do these steps in the **correct order**

- [ ] Add your package only as a `pub-dev` target in `.craft.yml`. (**not registry**)
  - The release process might fail if you add it to the registry at this point.
- [ ] Trigger the release
  - [ ] Check that the release bot successfully updated the versions in `version.dart` and `pubspec.yaml` in the release branch.

## After the first release

- [ ] Check if package is succesfully released on `pub.dev`
- [ ] Add the package to the Sentry Release Registry 
  - Instructions on how to do this can be found [here](https://github.com/getsentry/sentry-release-registry#adding-new-sdks)
  - [Example PR](https://github.com/getsentry/sentry-release-registry/pull/136)
- [ ] Add an entry to `.craft.yml` for the package in the `registry` section.
  - Now all future releases will be added to the registry automatically.
- [ ] Update the repo's `README.md`
- [ ] Prepare and merge [Sentry documentation](https://github.com/getsentry/sentry-docs/)

# Contributing to Mosaikk

Thanks for helping. Bug reports, translations and small, focused pull requests are all welcome.

## Building

Requires Xcode and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```sh
scripts/build.sh        # build/Mosaikk.app, signed to run locally
scripts/test.sh         # engine tests
scripts/preflight.sh    # tests, both release configurations, and shipping checks
scripts/snapshots.sh    # a scripted session captured into build/snapshots, for checking the interface by eye
```

Edit `project.yml`, not the `.xcodeproj`.

## Pull requests

- Keep one change per pull request, and describe how you tested it.
- `scripts/preflight.sh` must pass; for interface changes, include snapshots in light and dark.
- Mosaikk stays offline: no network access, analytics or third-party code.
- New user-facing text needs translations: add them to `scripts/translations.py` and run `scripts/localize.sh`.
- Test pictures are generated (`scripts/sample-photos.swift`); never commit personal photos.

By contributing you agree that your work is licensed under the [Apache License 2.0](LICENSE).

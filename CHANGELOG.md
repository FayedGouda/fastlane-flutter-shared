# Changelog

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog and this project adheres to Semantic Versioning.

## [Unreleased]
### Added
- Initial repository scaffolding (README, LICENSE, examples, CI, lint config)

### Changed
- Refactored iOS distribution flow by extracting shared pre-steps into a private helper lane.
- Updated IPA path resolution to detect artifacts from `build/ios/ipa/*.ipa` under the Flutter repo root.
- Simplified environment handling by removing flavor-specific `.env.*` mapping logic in lanes.
- Updated README to match the current exported lanes and options.

## [0.1.0] - 2025-11-02
### Added
- Shared Fastlane lanes: prepare_env_shared, bump_pubspec_version_shared, build_android_shared, distribute_android_shared

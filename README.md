# fastlane-flutter-shared

Reusable Fastlane lanes for Flutter apps. These lanes centralize common build and distribution steps so your Flutter projects can import and call them directly.

Android and iOS lanes are provided in the exported `Fastfile`.

## What you get

- `prepare_env`: Copies a flavor-specific `.env.*` to `.env` and can load it into the Fastlane process
- `bump_pubspec_version`: Increments pubspec patch version and build number
- `build_apk`: Builds a release APK for the given flavor
- `build_app_bundle`: Builds an Android App Bundle for the given flavor
- `distribute_apk_firebase`: Uploads the APK to Firebase App Distribution
- `build_ipa`: Builds an iOS IPA for the given flavor
- `distribute_ipa_testflight`: Uploads the IPA to TestFlight
- `distribute_ipa_app_store`: Uploads the IPA to App Store Connect

The old `*_shared` lane names were renamed to these shorter exported names.

## Prerequisites

- Flutter installed and available on PATH
- Your Flutter app uses Android flavors and has entrypoints like `lib/main_<flavor>.dart`
- `.env.*` files exist in your Flutter app repo root (same directory as `pubspec.yaml`), e.g. `.env.dev`, `.env.stg`, `.env.prod`
- Ruby + fastlane installed in the consuming app repository
- Firebase App Distribution plugin (only needed if you use `distribute_apk_firebase`):
  - Add to `Pluginfile` in the consuming app repo:
    ```ruby
    # Pluginfile
    gem 'fastlane-plugin-firebase_app_distribution'
    ```
  - Or install once via:
    ```sh
    fastlane add_plugin firebase_app_distribution
    ```

## How to use in a Flutter app repo

In your app’s `fastlane/Fastfile` (the consumer), import this Fastfile from Git and call the lanes:

```ruby
# fastlane/Fastfile (in your app repo)
default_platform(:android)

import_from_git(
  url: "git@github.com:YOUR_ORG/fastlane-flutter-shared.git", # or https URL
  path: "Fastfile",
  branch: "main" # or :tag => "v1.0.0" to pin
)

# Optional: wrap imported lanes with local defaults
lane :build_android do |options|
  build_apk(
    flavor: options[:flavor] || 'staging',
    target: options[:target] # defaults to lib/main_<flavor>.dart
  )
end
```

You can also import from a local checkout if that fits your workflow:

```ruby
import("../path/to/fastlane-flutter-shared/Fastfile")
```

## Environment and configuration

These lanes detect the app repo root by walking up to find `pubspec.yaml`. `.env` files must live at that root, for example:

```
my_flutter_app/
├─ pubspec.yaml
├─ .env.dev
├─ .env.stg
├─ .env.prod
└─ fastlane/
```

Default flavor-to-file mapping:
- develop/development/dev -> `.env.dev`
- staging/stage/stg -> `.env.stg`
- everything else -> `.env.prod`

You can override with `env_map`, e.g. `{ 'qa' => '.env.qa' }`.

If using Firebase App Distribution, set these in your environment or CI secrets in the consumer repo:
- `FIREBASE_CLI_TOKEN` – Firebase CI token
- `FIREBASE_APP_ID` – Firebase App ID (Android)
- `FIREBASE_TESTERS` – optional comma-separated tester emails
- `RELEASE_NOTES` – optional; defaults to the latest git commit message

## Lanes and options

### prepare_env
Copies the right `.env.*` to `.env` and optionally loads it into the Fastlane process using dotenv.

Options:
- `flavor` (String) – default `"production"`
- `load` / `load_into_fastlane` (Boolean) – default `false`
- `dest` (String) – default `".env"`
- `env_map` (Hash) – e.g. `{ 'qa' => '.env.qa' }`

Examples:
```sh
fastlane android prepare_env flavor:staging load:true
fastlane android prepare_env flavor:qa env_map:"{ qa: '.env.qa' }"
```

### bump_pubspec_version
Increments the patch number and build number in `pubspec.yaml` (`version: x.y.(z+1)+(build+1)`).

```sh
fastlane android bump_pubspec_version
```

### build_apk
Builds a release APK with Flutter for the given flavor.

Options:
- `flavor` (String) – default `"production"`
- `target` (String) – default `lib/main_<flavor>.dart`
- `copy_env` (Boolean) – default `true`
- `env_map` (Hash) – optional mapping

Output APK (by default): `build/app/outputs/flutter-apk/app-<flavor>-release.apk`

Examples:
```sh
fastlane android build_apk flavor:staging
fastlane android build_apk flavor:production target:"lib/main_production.dart"
```

### build_app_bundle
Builds an Android App Bundle with Flutter for the given flavor.

Options:
- `flavor` (String) – default `"production"`
- `target` (String) – default `lib/main_<flavor>.dart`
- `copy_env` (Boolean) – default `true`
- `env_map` (Hash) – optional mapping

Examples:
```sh
fastlane android build_app_bundle flavor:staging
```

### distribute_apk_firebase
Prepares env, uploads the APK, and can use release notes from the latest commit.

Options:
- `flavor` (String) – default `"production"`
- `target` (String) – default `lib/main_<flavor>.dart`
- `copy_env` (Boolean) – default `true`
- `env_map` (Hash)
- `apk_path` (String) – default `../build/app/outputs/flutter-apk/app-<flavor>-release.apk` (relative to `fastlane/` in the consumer repo)
- `bump` (Boolean) – default `true`
- `firebase_app_id` (String) – defaults to `ENV["FIREBASE_APP_ID"]`
- `firebase_cli_token` (String) – defaults to `ENV["FIREBASE_CLI_TOKEN"]`
- `testers` (String) – defaults to `ENV["FIREBASE_TESTERS"]`
- `release_notes` (String) – defaults to `ENV["RELEASE_NOTES"]` or last git commit message

Examples:
```sh
# Basic (uses env vars for credentials)
fastlane android distribute_apk_firebase flavor:staging

# Override APK path and provide explicit params
fastlane android distribute_apk_firebase \
  flavor:staging \
  apk_path:"../build/app/outputs/flutter-apk/app-staging-release.apk" \
  firebase_app_id:"1:1234567890:android:abc123" \
  testers:"dev1@example.com,dev2@example.com" \
  release_notes:"QA build"

# Skip version bump
fastlane android distribute_apk_firebase flavor:staging
```

### build_ipa
Builds an iOS IPA with Flutter for the given flavor.

Options:
- `flavor` (String) – default `"production"`
- `target` (String) – default `lib/main_<flavor>.dart`
- `copy_env` (Boolean) – default `true`
- `env_map` (Hash) – optional mapping

### distribute_ipa_testflight
Prepares env, bumps version, builds, and uploads the IPA to TestFlight.

Options:
- `flavor` (String) – default `"production"`
- `target` (String) – default `lib/main_<flavor>.dart`
- `copy_env` (Boolean) – default `true`
- `env_map` (Hash)
- `bump` (Boolean) – default `true`
- `ipa_path` (String) – default auto-detected from `../build/ios/ipa/`
- `groups` (String) – defaults to `ENV["TESTFLIGHT_GROUPS"]`

### distribute_ipa_app_store
Prepares env, bumps version, builds, and uploads the IPA to App Store Connect.

Options:
- `flavor` (String) – default `"production"`
- `target` (String) – default `lib/main_<flavor>.dart`
- `copy_env` (Boolean) – default `true`
- `env_map` (Hash)
- `bump` (Boolean) – default `true`
- `ipa_path` (String) – default auto-detected from `../build/ios/ipa/`

## Tips & troubleshooting

- If `.env` isn’t being copied, confirm your `.env.*` files live next to `pubspec.yaml` and the flavor name matches mapping rules.
- If the APK path differs in your project, pass `apk_path` explicitly to `distribute_apk_firebase`.
- Ensure `flutter` is available on PATH in CI. Consider running `flutter --version` as a quick sanity check (the lane does this already).
- To pin this shared repo to a stable release, import with a tag: `tag: "v1.0.0"`.

## Roadmap

- Add sample CI pipelines (GitHub Actions, Bitrise) that call these lanes

# fastlane-flutter-shared

Reusable Fastlane lanes for Flutter apps (Android). These lanes centralize common build and distribution steps so your Flutter projects can import and call them directly.

Currently Android lanes are provided; iOS can be added using the same pattern.

## What you get

- prepare_env_shared: Copies a flavor-specific `.env.*` to `.env` (optionally loads it into Fastlane process)
- bump_pubspec_version_shared: Increments pubspec patch version and build number
- build_android_shared: Builds a release APK for the given flavor
- distribute_android_shared: Builds and uploads the APK to Firebase App Distribution

## Prerequisites

- Flutter installed and available on PATH
- Your Flutter app uses Android flavors and has entrypoints like `lib/main_<flavor>.dart`
- `.env.*` files exist in your Flutter app repo root (same directory as `pubspec.yaml`), e.g. `.env.dev`, `.env.stg`, `.env.prod`
- Ruby + fastlane installed in the consuming app repository
- Firebase App Distribution plugin (only needed if you use `distribute_android_shared`):
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

# Optional: wrap shared lanes with local defaults
lane :build_android do |options|
  build_android_shared(
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

### prepare_env_shared
Copies the right `.env.*` to `.env` and optionally loads it into the Fastlane process using dotenv.

Options:
- `flavor` (String) – default `"production"`
- `load` / `load_into_fastlane` (Boolean) – default `false`
- `dest` (String) – default `".env"`
- `env_map` (Hash) – e.g. `{ 'qa' => '.env.qa' }`

Examples:
```sh
fastlane android prepare_env_shared flavor:staging load:true
fastlane android prepare_env_shared flavor:qa env_map:"{ qa: '.env.qa' }"
```

### bump_pubspec_version_shared
Increments the patch number and build number in `pubspec.yaml` (`version: x.y.(z+1)+(build+1)`).

```sh
fastlane android bump_pubspec_version_shared
```

### build_android_shared
Builds a release APK with Flutter for the given flavor.

Options:
- `flavor` (String) – default `"production"`
- `target` (String) – default `lib/main_<flavor>.dart`
- `copy_env` (Boolean) – default `true`
- `env_map` (Hash) – optional mapping

Output APK (by default): `build/app/outputs/flutter-apk/app-<flavor>-release.apk`

Examples:
```sh
fastlane android build_android_shared flavor:staging
fastlane android build_android_shared flavor:production target:"lib/main_production.dart"
```

### distribute_android_shared
Prepares env, bumps version (can be disabled), builds, and uploads the APK to Firebase App Distribution.

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
fastlane android distribute_android_shared flavor:staging

# Override APK path and provide explicit params
fastlane android distribute_android_shared \
  flavor:staging \
  apk_path:"../build/app/outputs/flutter-apk/app-staging-release.apk" \
  firebase_app_id:"1:1234567890:android:abc123" \
  testers:"dev1@example.com,dev2@example.com" \
  release_notes:"QA build"

# Skip version bump
fastlane android distribute_android_shared flavor:staging bump:false
```

## Tips & troubleshooting

- If `.env` isn’t being copied, confirm your `.env.*` files live next to `pubspec.yaml` and the flavor name matches mapping rules.
- If the APK path differs in your project, pass `apk_path` explicitly to `distribute_android_shared`.
- Ensure `flutter` is available on PATH in CI. Consider running `flutter --version` as a quick sanity check (the lane does this already).
- To pin this shared repo to a stable release, import with a tag: `tag: "v1.0.0"`.

## Roadmap

- Add iOS lanes mirroring the Android flow
- Add sample CI pipelines (GitHub Actions, Bitrise) that call these lanes

require 'dotenv/load'
require 'fileutils'
require 'yaml'
########################## Shared Helper Methods ##########################
def find_repo_root(start = Dir.pwd)
  dir = File.expand_path(start)
  10.times do
    return dir if File.exist?(File.join(dir, 'pubspec.yaml'))
    parent = File.expand_path('..', dir)
    break if parent == dir
    dir = parent
  end
  UI.user_error!("Could not locate repo root containing pubspec.yaml from #{start}")
end

def bump_version_in_pubspec
  root = find_repo_root
  pubspec = File.join(root, 'pubspec.yaml')
  content = File.read(pubspec)
  m = content.match(/^version:\s*(\d+\.\d+\.\d+)\+(\d+)/)
  UI.user_error!("version not found in pubspec.yaml") unless m

  parts = m[1].split('.')
  parts[2] = (parts[2].to_i + 1).to_s
  new_version = parts.join('.')
  build = m[2].to_i + 1

  File.write(pubspec, content.gsub(/^version: .+$/, "version: #{new_version}+#{build}"))
  UI.success("Updated pubspec.yaml to version: #{new_version}+#{build}")
end

def get_release_notes(options = {})
  options[:release_notes] || ENV["RELEASE_NOTES"] || Actions.sh("git", "log", "-1", "--pretty=%B").strip
end

def flutter_build(flavor, target, build_type)
  sh "flutter --version"
  # sh "flutter clean"
  if build_type == 'ipa'
    # For iOS we rely on Xcode's build system to handle flavors, so we just specify the target and let it do its thing.
    Bundler.with_original_env do
      sh "flutter build #{build_type} --release -t #{target}"
    end
  else
    sh "flutter build #{build_type} --release --flavor #{flavor} -t #{target}"
  end
end

def resolve_android_apk_path(flavor:, apk_path: nil)
  return File.expand_path(apk_path, Dir.pwd) if apk_path

  root = find_repo_root
  File.join(root, 'build', 'app', 'outputs', 'flutter-apk', "app-#{flavor}-release.apk")
end

def require_env!(key)
  value = ENV[key]
  UI.user_error!("Missing required ENV[#{key}] for Firebase distribution") if value.nil? || value.strip.empty?
  value
end

########################## Android Platform ##########################

default_platform(:android)

platform :android do
  desc "Build Android APK"
  lane :build_apk do |options|
    flavor = options[:flavor] || 'production'
    target = options[:target] || "lib/main_#{flavor}.dart"
    flutter_build(flavor, target, 'apk')
  end

  desc "Build Android App Bundle"
  lane :build_app_bundle do |options|
    flavor = options[:flavor] || 'production'
    target = options[:target] || "lib/main_#{flavor}.dart"
    flutter_build(flavor, target, 'appbundle')
  end

  desc "Distribute APK to Firebase App Distribution"
  lane :distribute_apk_firebase do |options|
    flavor = options[:flavor] || 'production'
    build_apk(flavor: flavor, target: options[:target] || "lib/main_#{flavor}.dart")
    apk_path = resolve_android_apk_path(flavor: flavor, apk_path: options[:apk_path])
    release_notes = get_release_notes(options)

    app_id = options[:firebase_app_id] || require_env!("FIREBASE_APP_ID")
    cli_token = options[:firebase_cli_token] || require_env!("FIREBASE_CLI_TOKEN")
    testers = options[:testers] || require_env!("FIREBASE_TESTERS")

    UI.user_error!("APK not found at #{apk_path}") unless File.exist?(apk_path)
    UI.message("Uploading APK from: #{apk_path}")
    
    firebase_app_distribution(
      app: app_id,
      firebase_cli_token: cli_token,
      android_artifact_type: "APK",
      android_artifact_path: apk_path,
      testers: testers,
      release_notes: release_notes
    )
  end
end

########################## iOS Platform ##########################

platform :ios do

  # Global configuration that runs before any lane
  before_all do |lane, options|
    # Setup App Store Connect API Key for all distribution tasks
    configure_asc_api_key(options)
    
    # Creates a temporary keychain on CI to avoid permission prompts
    setup_ci if ENV["CI"] || ENV["GITHUB_ACTIONS"]
  end

  desc "Push a new beta build to TestFlight"
  lane :beta do |options|
    # 1. Configuration & Defaults
    app_id = options[:app_identifier] || CredentialsManager::AppfileConfig.try_fetch_value(:app_identifier)
    UI.user_error!("App Identifier is missing!") unless app_id

    # 1. RUN THE CHECK FIRST (Fails early to save time)
    # We pass the app_id so it knows which app to check on Apple's servers
    validate_version_is_higher(app_id: app_id)

    # 2. Sync Manual Signing (Certificates & Profiles)
    # match ensures the correct 'match AppStore ...' profile is on the machine
    match(
      app_identifier: app_id,
      type: options[:match_type] || "appstore",
      readonly: is_ci
    )

    # 3. Clean and Prep Pods
    cocoapods(clean_install: true)

    # 4. Flutter Build (Compile only)
    # We build the 'ios' target without signing to let Fastlane handle the identity
    target = options[:flutter_target] || "lib/main.dart"
    UI.message("Building Flutter iOS app with target: #{target}")
    sh("flutter build ios --release --no-codesign")

    # 5. Build and Sign the IPA
    # This uses the 'match' profiles we just downloaded
    ipa_path = build_app(
      workspace: "Runner.xcworkspace",
      scheme: "Runner",
      export_method: "app-store",
      export_options: {
        provisioningProfiles: {
          app_id => "match AppStore #{app_id}"
        }
      }
    )
      UI.success("IPA built at: #{ipa_path}")
    # 6. Upload to TestFlight
    upload_to_testflight(
      ipa: ipa_path,
      changelog: get_release_notes(options),
      groups: options[:groups] || ENV["TESTFLIGHT_GROUPS"],
      skip_waiting_for_build_processing: options.fetch(:skip_wait, true)
    )
  end

  desc "Promote build to App Store"
  lane :release do |options|
    # Reuses the beta lane to build, but uploads to App Store instead
    # You can also use 'upload_to_app_store' if you have an existing IPA
    beta(options) 
    
    upload_to_app_store(
      force: true,
      skip_screenshots: true,
      skip_metadata: true
    )
  end

  # --- Private Helper Lanes ---

  private_lane :configure_asc_api_key do |options|
    key_id = options[:api_key_id] || ENV["APP_STORE_CONNECT_API_KEY_ID"]
    issuer_id = options[:api_key_issuer_id] || ENV["APP_STORE_CONNECT_API_ISSUER_ID"]
    key_content = options[:api_key_base64] || ENV["APP_STORE_CONNECT_API_KEY_BASE64"]
    
    if key_id && issuer_id && key_content
      app_store_connect_api_key(
        key_id: key_id,
        issuer_id: issuer_id,
        key_content: key_content,
        is_key_content_base64: true
      )
    else
      UI.important("ASC API Key not found. Falling back to session/password if available.")
    end
  end

  private_lane :validate_version_is_higher do |options|
  app_id = options[:app_id]
  
  # 1. Get the current ceiling from Apple
  UI.message("🔍 Fetching latest build from TestFlight...")
  latest_tf_build = latest_testflight_build_number(
    app_identifier: app_id,
    initial_build_number: 1
  )

  UI.message("Latest TestFlight build number: #{latest_tf_build}")

  # 2. Read pubspec.yaml directly (2 levels up from /ios/fastlane)
  pubspec_path = File.expand_path("../../pubspec.yaml", Dir.pwd)
  
  begin
    pubspec = YAML.load_file(pubspec_path)
    version_line = pubspec['version'] # e.g., "1.2.1+24"
    # Logic: Split by '+', take the last part, turn into integer
    local_build_number = version_line.split('+').last.to_i
  rescue => e
    UI.user_error!("❌ Error reading pubspec.yaml: #{e.message}")
  end

  UI.message("--- Version Sync Check ---")
  UI.message("TestFlight Build: #{latest_tf_build}")
  UI.message("Pubspec Build:    #{local_build_number}")
  UI.message("--------------------------")

  # 3. Validation
  if local_build_number <= latest_tf_build
    UI.user_error!("❌ STOP: Your pubspec.yaml build number (#{local_build_number}) must be higher than TestFlight (#{latest_tf_build}). Update pubspec.yaml and try again.")
  end

  UI.success("✅ Version check passed. Flutter build will use: #{version_line}")
end

  
end

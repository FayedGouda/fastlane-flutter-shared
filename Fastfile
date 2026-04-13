require 'dotenv'
require 'fileutils'

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

def map_env_file(flavor, root, env_map = nil)
  f = flavor.to_s.downcase
  return File.join(root, env_map[f]) if env_map && env_map[f]
  return File.join(root, '.env.dev') if %w[develop development dev].include?(f)
  return File.join(root, '.env.stg') if %w[staging stage stg].include?(f)
  File.join(root, '.env.prod')
end

def do_prepare_env(flavor:, load_into_fastlane: false, dest: '.env', env_map: nil)
  root = find_repo_root
  env_path = map_env_file(flavor, root, env_map)
  UI.message("Using env file: #{env_path}")
  UI.user_error!("Env file not found: #{env_path}") unless File.exist?(env_path)
  Dotenv.overload(env_path) if load_into_fastlane
  FileUtils.cp(env_path, File.join(root, dest))
  UI.success("Copied #{env_path} -> #{File.join(root, dest)}")
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
  sh "flutter clean"
  sh "flutter build #{build_type} --release --flavor #{flavor} -t #{target}"
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
    copy_env = options.fetch(:copy_env, true)
    env_map = options[:env_map]

    prepare_env(flavor: flavor, load: false, env_map: env_map) if copy_env
    flutter_build(flavor, target, 'apk')
  end

  desc "Build Android App Bundle"
  lane :build_app_bundle do |options|
    flavor = options[:flavor] || 'production'
    target = options[:target] || "lib/main_#{flavor}.dart"
    copy_env = options.fetch(:copy_env, true)
    env_map = options[:env_map]

    prepare_env(flavor: flavor, load: false, env_map: env_map) if copy_env
    flutter_build(flavor, target, 'appbundle')
  end

  desc "Distribute APK to Firebase App Distribution"
  lane :distribute_apk_firebase do |options|
    flavor = options[:flavor] || 'production'
    # build_apk(flavor: flavor, target: options[:target] || "lib/main_#{flavor}.dart", copy_env: options.fetch(:copy_env, true), env_map: options[:env_map])
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
  desc "Build iOS IPA"
  lane :build_ipa do |options|
    flavor = options[:flavor] || 'production'
    target = options[:target] || "lib/main_#{flavor}.dart"
    copy_env = options.fetch(:copy_env, true)
    env_map = options[:env_map]

    prepare_env(flavor: flavor, load: false, env_map: env_map) if copy_env
    flutter_build(flavor, target, 'ipa')
  end

  private_lane :configure_asc_api_key do |options|
    key_path = options[:api_key_path] || ENV["APP_STORE_CONNECT_API_KEY_PATH"]
    key_id = options[:api_key_id] || ENV["APP_STORE_CONNECT_API_KEY_ID"]
    issuer_id = options[:api_key_issuer_id] || ENV["APP_STORE_CONNECT_API_ISSUER_ID"]
    key_b64 = options[:api_key_base64] || ENV["APP_STORE_CONNECT_API_KEY"]

    if key_path && key_id && issuer_id
      app_store_connect_api_key(
        key_id: key_id,
        issuer_id: issuer_id,
        key_filepath: key_path,
        is_key_content_base64: false
      )
    elsif key_b64 && key_id && issuer_id
      app_store_connect_api_key(
        key_id: key_id,
        issuer_id: issuer_id,
        key_content: key_b64,
        is_key_content_base64: true
      )
    else
      UI.message("No App Store Connect API key configured")
    end
  end

  desc "Upload iOS build to TestFlight"
  lane :distribute_ipa_testflight do |options|
    flavor = options[:flavor] || 'production'
    target = options[:target] || "lib/main_#{flavor}.dart"
    copy_env = options.fetch(:copy_env, true)
    env_map = options[:env_map]
    bump = options.fetch(:bump, true)

    prepare_env(flavor: flavor, load: true, env_map: env_map) if copy_env
    bump_pubspec_version if bump
    build_ipa(flavor: flavor, target: target, copy_env: false, env_map: env_map)

    ipa_path = options[:ipa_path] || find_ipa
    release_notes = get_release_notes(options)
    
    configure_asc_api_key(options)

    upload_to_testflight(
      ipa: ipa_path,
      changelog: release_notes,
      groups: options[:groups] || ENV["TESTFLIGHT_GROUPS"],
      skip_waiting_for_build_processing: options.fetch(:skip_wait, false)
    )
  end

  desc "Upload iOS build to App Store"
  lane :distribute_ipa_app_store do |options|
    flavor = options[:flavor] || 'production'
    target = options[:target] || "lib/main_#{flavor}.dart"
    copy_env = options.fetch(:copy_env, true)
    env_map = options[:env_map]
    bump = options.fetch(:bump, true)

    prepare_env(flavor: flavor, load: true, env_map: env_map) if copy_env
    bump_pubspec_version if bump
    build_ipa(flavor: flavor, target: target, copy_env: false, env_map: env_map)

    ipa_path = options[:ipa_path] || find_ipa
    configure_asc_api_key(options)

    upload_to_app_store(
      ipa: ipa_path,
      skip_screenshots: true,
      skip_metadata: true,
      force: true,
      submit_for_review: options.fetch(:submit_for_review, false),
      automatic_release: options.fetch(:automatic_release, false)
    )
  end

  private_lane :find_ipa do
    ipa_path = Actions.sh("bash", "-lc", "ls ../build/ios/ipa/*.ipa | head -n1").strip
    UI.user_error!("IPA not found at ../build/ios/ipa/*.ipa") if ipa_path.nil? || ipa_path.empty?
    ipa_path
  end
end

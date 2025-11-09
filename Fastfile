# Fastfile (shared repo)
# Exposes reusable lanes for Flutter projects (Android-ready; iOS can be added similarly)
require 'dotenv'
require 'fileutils'

default_platform(:android)

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

desc "Prepare .env for a flavor"
lane :prepare_env do |options|
  do_prepare_env(
    flavor: options[:flavor] || 'production',
    load_into_fastlane: options[:load] || options[:load_into_fastlane] || false,
    dest: options[:dest] || '.env',
    env_map: options[:env_map]
  )
end

desc "Bump pubspec version patch and build"
lane :bump_pubspec_version do
  root = find_repo_root
  pubspec = File.join(root, 'pubspec.yaml')
  content = File.read(pubspec)
  m = content.match(/^version:\s*(\d+\.\d+\.\d+)\+(\d+)/)
  UI.user_error!("version not found in pubspec.yaml") unless m
  parts = m[1].split('.'); parts[2] = (parts[2].to_i + 1).to_s
  new_version = parts.join('.'); build = m[2].to_i + 1
  File.write(pubspec, content.gsub(/^version: .+$/, "version: #{new_version}+#{build}"))
  UI.success("Updated pubspec.yaml to version: #{new_version}+#{build}")
end

platform :android do
  desc "Build Android APK"
  lane :build_android do |options|
    flavor   = options[:flavor] || 'production'
    target   = options[:target] || "lib/main_#{flavor}.dart"
    copy_env = options.fetch(:copy_env, true)
    env_map  = options[:env_map]

    prepare_env(flavor: flavor, load: false, env_map: env_map) if copy_env
    sh "flutter --version"
    sh "flutter clean"
    sh "flutter build apk --release --flavor #{flavor} -t #{target}"
  end

  desc "Build Android app bundle"
  lane :build_android_app_bundle do |options|
    flavor   = options[:flavor] || 'production'
    target   = options[:target] || "lib/main_#{flavor}.dart"
    copy_env = options.fetch(:copy_env, true)
    env_map  = options[:env_map]

    prepare_env(flavor: flavor, load: false, env_map: env_map) if copy_env
    sh "flutter --version"
    sh "flutter clean"
    sh "flutter build appbundle --release --flavor #{flavor} -t #{target}"
  end

  desc "Distribute APK to Firebase App Distribution"
  lane :distribute_android_to_firebase do |options|
    flavor   = options[:flavor] || 'production'
    target   = options[:target] || "lib/main_#{flavor}.dart"
    copy_env = options.fetch(:copy_env, true)
    env_map  = options[:env_map]
    apk_path = options[:apk_path] || "../build/app/outputs/flutter-apk/app-#{flavor}-release.apk"

    prepare_env(flavor: flavor, load: true, env_map: env_map) if copy_env
    bump_pubspec_version if options.fetch(:bump, true)
    build_android(flavor: flavor, target: target, copy_env: false, env_map: env_map)

    release_notes = options[:release_notes] || ENV["RELEASE_NOTES"] || Actions.sh("git", "log", "-1", "--pretty=%B").strip

    firebase_app_distribution(
      app: options[:firebase_app_id] || ENV["FIREBASE_APP_ID"],
      firebase_cli_token: options[:firebase_cli_token] || ENV["FIREBASE_CLI_TOKEN"],
      android_artifact_type: "APK",
      android_artifact_path: apk_path,
      testers: options[:testers] || ENV["FIREBASE_TESTERS"],
      release_notes: release_notes
    )
  end
end
# Shared helper functions for Flutter lanes

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

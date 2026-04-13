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
  bump_version_in_pubspec
end

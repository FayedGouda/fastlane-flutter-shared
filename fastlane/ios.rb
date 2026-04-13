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

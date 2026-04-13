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

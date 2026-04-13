require 'dotenv'
require 'fileutils'

def import_local(relative_path)
  caller = caller_locations(1, 1).first
  source_file = caller&.absolute_path || caller&.path
  base_dir = File.dirname(source_file || __FILE__)
  resolved = File.expand_path(relative_path, base_dir)

  unless File.exist?(resolved)
    UI.user_error!("Could not resolve import: #{relative_path} from #{base_dir} (looked for #{resolved})")
  end

  import resolved
end

# Import shared helpers and lanes
import_local 'fastlane/shared_helpers.rb'
import_local 'fastlane/shared_lanes.rb'
import_local 'fastlane/android.rb'
import_local 'fastlane/ios.rb'

default_platform(:android)

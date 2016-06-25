module Fastlane
  class CrashlyticsBeta
    def run
      UI.user_error!('Beta by Crashlytics configuration is currently only available for iOS projects.') unless Setup.new.is_ios?
      config = {}
      FastlaneCore::Project.detect_projects(config)
      project = FastlaneCore::Project.new(config)
      keys = keys_from_project(project)

      if FastlaneFolder.setup?
        UI.header('Copy and paste the following lane into your Fastfile to use Crashlytics Beta!')
        puts lane_template(keys[:api_key], keys[:build_secret], project.schemes.first).cyan
      else
        fastfile = fastfile_template(keys[:api_key], keys[:build_secret], project.schemes.first)
        FileUtils.mkdir_p('fastlane')
        File.write('fastlane/Fastfile', fastfile)
      end
    end

    def keys_from_project(project)
      require 'xcodeproj'
      target_name = project.default_build_settings(key: 'TARGETNAME')
      path = project.is_workspace ? project.path.gsub('xcworkspace', 'xcodeproj') : project.path
      UI.crash!("No project available at path #{path}") unless File.exist?(path)
      xcode_project = Xcodeproj::Project.open(path)
      target = xcode_project.targets.find { |t| t.name == target_name }
      scripts = target.build_phases.select { |t| t.class == Xcodeproj::Project::Object::PBXShellScriptBuildPhase }
      crash_script = scripts.find { |s| includes_run_script?(s.shell_script) }
      UI.user_error!("Unable to find Crashlytics Run Script Build Phase") if crash_script.nil?
      script_array = crash_script.shell_script.split('\n').find { |l| includes_run_script?(l) }.split(' ')
      if script_array.count == 3 && api_key_valid?(script_array[1]) && build_secret_valid?(script_array[2])
        {
          api_key: script_array[1],
          build_secret: script_array[2]
        }
      else
        UI.important('Please enter your API Key and Build Secret:')
        keys = {}
        loop do
          keys[:api_key] = UI.input('API Key:')
          break if api_key_valid?(keys[:api_key])
          UI.important "Invalid API Key, Please Try Again!"
        end
        loop do
          keys[:build_secret] = UI.input('Build Secret:')
          break if build_secret_valid?(keys[:build_secret])
          UI.important "Invalid Build Secret, Please Try Again!"
        end
        keys
      end
    end

    def api_key_valid?(key)
      key.to_s.length == 40
    end

    def build_secret_valid?(secret)
      secret.to_s.length == 64
    end

    def includes_run_script?(string)
      string.include?('Fabric/run') || string.include?('Crashlytics/run') || string.include?('Fabric.framework/run') || string.include?('Crashlytics.framework/run')
    end

    def lane_template(api_key, build_secret, scheme)
      %{
  lane :beta do
    gym(scheme: '#{scheme}')
    crashlytics(api_token: '#{api_key}',
             build_secret: '#{build_secret}')
  end
      }
    end

    def fastfile_template(api_key, build_secret, scheme)
      <<-eos
fastlane_version "1.93.0"
default_platform :ios
platform :ios do
  lane :beta do
    gym(scheme: '#{scheme}')
    crashlytics(api_token: '#{api_key}',
             build_secret: '#{build_secret}')
  end
end
eos
    end
  end
end

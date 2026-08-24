require "rake"
require "shellwords"
require "asyncapi_cable/generator/rake_task_support"

module AsyncapiCable
  # The Rails engine picks up lib/tasks/*.rake on its own; other hosts add
  #
  #   require "asyncapi_cable/rake_tasks"
  #
  # to their Rakefile. Both routes end up here, so the task is defined once.
  module RakeTasks
    extend Rake::DSL

    def self.install!
      return if Rake::Task.task_defined?("asyncapi_cable:generate")

      namespace :asyncapi_cable do
        desc "Generate AsyncAPI 3 documents for ActionCable channels. " \
             "FRAMEWORK=rspec|minitest|hybrid, PATTERN= comma-separated globs of declaration files."
        task :generate do
          support = AsyncapiCable::Generator::RakeTaskSupport
          framework = ENV.fetch("FRAMEWORK") { support.detect_test_framework }.to_s
          pattern = ENV.fetch("PATTERN") { support.default_pattern_for(framework) }

          # A subprocess so the host boots in its own test environment and the
          # suppressors are installed before anything else is required — same
          # arrangement as `openapi_ruby:generate`.
          script = support.generate_script(framework, pattern)
          command = "bundle exec ruby -e #{Shellwords.escape(script)}"

          puts "Generating AsyncAPI documents (#{framework})..."
          system(support.subprocess_env, command) || abort("AsyncAPI generation failed")
        end
      end
    end
  end
end

AsyncapiCable::RakeTasks.install!

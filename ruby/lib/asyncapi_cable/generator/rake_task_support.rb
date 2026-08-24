require "openapi_ruby"
require "openapi_ruby/generator/rake_task_support"
require "asyncapi_cable/generator/declaration_loader"

module AsyncapiCable
  module Generator
    # Helpers backing the `asyncapi_cable:generate` rake task. Framework
    # detection and the subprocess environment are openapi-ruby's: the two
    # generators run against the same host, and a second copy of that logic
    # would drift from the one the OpenAPI schema is generated with.
    module RakeTaskSupport
      module_function

      def detect_test_framework
        OpenapiRuby::Generator::RakeTaskSupport.detect_test_framework
      end

      def default_pattern_for(framework)
        DeclarationLoader.validate_framework!(framework)

        case framework
        when "rspec" then "spec/**/*_spec.rb"
        when "minitest" then "test/**/*_test.rb"
        when "hybrid" then "spec/**/*_spec.rb,test/**/*_test.rb"
        end
      end

      # `OPENAPI_RUBY_GENERATING` comes along on purpose: host test helpers
      # guard their test-framework requires with
      # `unless OpenapiRuby.schema_generating?`, and a cable generation run is
      # the same kind of run — files are loaded for their declarations, never
      # executed — so that guard has to fire here too.
      def subprocess_env
        OpenapiRuby::Generator::RakeTaskSupport
          .subprocess_env
          .merge("ASYNCAPI_CABLE_GENERATING" => "true")
      end

      def generate_script(framework, pattern)
        DeclarationLoader.validate_framework!(framework)

        <<~RUBY
          require "asyncapi_cable/generator/runner"
          AsyncapiCable::Generator::Runner.call(
            framework: #{framework.inspect},
            pattern: #{pattern.inspect}
          )
        RUBY
      end
    end
  end
end

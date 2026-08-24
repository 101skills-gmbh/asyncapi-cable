require "asyncapi_cable"

module AsyncapiCable
  module Generator
    # Loads the spec/test files that carry `channel` declarations so the
    # MetadataStore holds them. Both the generator and the channel-coverage
    # gate need exactly that, in whichever framework the host writes its
    # declarations.
    #
    # Loading must not *run* the files. Both suppressors come from
    # openapi-ruby rather than being reimplemented here: they work around
    # another library's `at_exit` and schema-check behaviour, and two copies
    # of that would drift.
    module DeclarationLoader
      FRAMEWORKS = %w[rspec minitest hybrid].freeze

      module_function

      # The adapter has to be live before a declaration file loads — its class
      # body is what calls the DSL.
      def install_adapters!(framework)
        validate_framework!(framework)

        if framework != "minitest"
          require "rspec/core"
          require "asyncapi_cable/rspec"
        end

        require "asyncapi_cable/minitest" if framework != "rspec"
      end

      def suppress_side_effects!
        require "openapi_ruby/generator/autorun_suppressor"
        require "openapi_ruby/generator/test_schema_suppressor"

        OpenapiRuby::Generator::AutorunSuppressor.install!
        OpenapiRuby::Generator::TestSchemaSuppressor.install!
      end

      # Announced through the environment so a host test helper guarding on
      # either flag skips its test-time setup. In-process callers (the
      # channel-coverage gate) need this as much as the generation subprocess,
      # and it is not restored afterwards: the files loaded under the guard
      # stay loaded, so pretending the run is over would be a lie.
      def announce_declaration_run!
        ENV["ASYNCAPI_CABLE_GENERATING"] ||= "true"
        ENV["OPENAPI_RUBY_GENERATING"] ||= "true"
      end

      # Returns the files that were loaded, in load order.
      def load!(framework:, pattern:)
        install_adapters!(framework)
        announce_declaration_run!
        suppress_side_effects!

        globs_for(pattern).flat_map { |dir, glob| load_glob(dir, glob) }
      end

      # Each glob is loaded with its own framework directory at the head of
      # `$LOAD_PATH`, so the `require "rails_helper"` / `require "test_helper"`
      # at the top of a declaration file resolves to the right helper. Spec
      # globs load before test globs, matching openapi-ruby's hybrid script.
      def globs_for(pattern)
        globs = pattern.to_s.split(",").map(&:strip).reject(&:empty?)
        spec_globs = globs.grep(%r{\bspec/})
        test_globs = globs.grep(%r{\btest/})

        spec_globs.map { |glob| ["spec", glob] } +
          test_globs.map { |glob| ["test", glob] } +
          (globs - spec_globs - test_globs).map { |glob| [nil, glob] }
      end

      def load_glob(dir, glob)
        # A glob can legitimately resolve directories (`test/asyncapi/**`);
        # `require` on one raises LoadError.
        files = Dir.glob(glob).select { |file| File.file?(file) }.sort
        return [] if files.empty?
        return files.each { |file| require File.expand_path(file) } if dir.nil?

        path = File.expand_path(dir)
        added = !$LOAD_PATH.include?(path)
        $LOAD_PATH.unshift(path) if added
        begin
          files.each { |file| require File.expand_path(file) }
        ensure
          $LOAD_PATH.delete(path) if added
        end
      end

      def validate_framework!(framework)
        return if FRAMEWORKS.include?(framework)

        raise ArgumentError,
          "Unknown test framework #{framework.inspect}. Expected one of #{FRAMEWORKS.join(", ")}."
      end
    end
  end
end

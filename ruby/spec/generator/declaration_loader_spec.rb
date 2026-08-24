require "spec_helper"
require "asyncapi_cable/generator/declaration_loader"

RSpec.describe AsyncapiCable::Generator::DeclarationLoader do
  let(:fixture_glob) { "spec/fixtures/declarations/*_declaration.rb" }

  describe ".globs_for" do
    it "loads spec globs before test globs" do
      mapped = described_class.globs_for("test/asyncapi/**/*_test.rb, spec/asyncapi/**/*_spec.rb")

      expect(mapped).to eq([
        ["spec", "spec/asyncapi/**/*_spec.rb"],
        ["test", "test/asyncapi/**/*_test.rb"]
      ])
    end

    it "maps a pack glob to the framework directory it belongs to" do
      mapped = described_class.globs_for("packs/*/test/asyncapi/**/*_test.rb")

      expect(mapped).to eq([["test", "packs/*/test/asyncapi/**/*_test.rb"]])
    end

    it "leaves a glob belonging to neither framework directory unmapped" do
      mapped = described_class.globs_for("lib/declarations/*.rb")

      expect(mapped).to eq([[nil, "lib/declarations/*.rb"]])
    end

    it "ignores empty entries" do
      expect(described_class.globs_for("spec/a_spec.rb, ,")).to eq([["spec", "spec/a_spec.rb"]])
    end
  end

  describe ".validate_framework!" do
    it "raises for an unknown framework" do
      expect { described_class.validate_framework!("rspec2") }
        .to raise_error(ArgumentError, /Unknown test framework "rspec2"/)
    end

    it "accepts the three supported frameworks" do
      described_class::FRAMEWORKS.each do |framework|
        expect { described_class.validate_framework!(framework) }.not_to raise_error
      end
    end
  end

  describe ".load!" do
    it "registers a Minitest-DSL declaration in the MetadataStore" do
      described_class.load!(framework: "minitest", pattern: fixture_glob)

      contexts = AsyncapiCable::Dsl::MetadataStore.contexts_for(:declaration_loader_fixture)
      expect(contexts.map(&:stream_template)).to include("{user_id}-loader-fixture")
    end

    it "returns the loaded files" do
      loaded = described_class.load!(framework: "minitest", pattern: fixture_glob)

      expect(loaded).to include(a_string_matching(%r{declarations/minitest_channel_declaration\.rb\z}))
    end

    it "skips directories a glob resolves to" do
      expect { described_class.load!(framework: "minitest", pattern: "spec/fixtures/declarations/**") }
        .not_to raise_error
    end

    it "returns an empty list when nothing matches" do
      expect(described_class.load!(framework: "hybrid", pattern: "spec/nowhere/**/*_spec.rb")).to eq([])
    end

    it "suppresses the autorun and test-schema side effects before loading" do
      expect(OpenapiRuby::Generator::AutorunSuppressor).to receive(:install!)
      expect(OpenapiRuby::Generator::TestSchemaSuppressor).to receive(:install!)

      described_class.load!(framework: "minitest", pattern: fixture_glob)
    end

    it "announces the run so host test-helper guards fire" do
      flags = %w[ASYNCAPI_CABLE_GENERATING OPENAPI_RUBY_GENERATING]
      original = flags.to_h { |var| [var, ENV[var]] }
      flags.each { |var| ENV.delete(var) }

      begin
        described_class.load!(framework: "minitest", pattern: fixture_glob)

        expect(ENV.values_at(*flags)).to eq(%w[true true])
      ensure
        original.each { |var, value| value.nil? ? ENV.delete(var) : ENV[var] = value }
      end
    end

    it "rejects an unknown framework before loading anything" do
      expect(Dir).not_to receive(:glob)

      expect { described_class.load!(framework: "cucumber", pattern: fixture_glob) }
        .to raise_error(ArgumentError)
    end
  end

  describe ".install_adapters!" do
    it "makes the Minitest DSL available" do
      described_class.install_adapters!("minitest")

      expect(defined?(AsyncapiCable::Adapters::Minitest::DSL)).to eq("constant")
    end

    it "makes both DSLs available in hybrid mode" do
      described_class.install_adapters!("hybrid")

      expect(defined?(AsyncapiCable::Adapters::RSpec::ExampleGroupHelpers)).to eq("constant")
      expect(defined?(AsyncapiCable::Adapters::Minitest::DSL)).to eq("constant")
    end
  end
end

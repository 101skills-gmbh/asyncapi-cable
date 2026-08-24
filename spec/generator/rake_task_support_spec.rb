require "spec_helper"
require "asyncapi_cable/generator/rake_task_support"

RSpec.describe AsyncapiCable::Generator::RakeTaskSupport do
  describe ".detect_test_framework" do
    it "delegates to openapi-ruby, so both generators agree on the host" do
      expect(OpenapiRuby::Generator::RakeTaskSupport)
        .to receive(:detect_test_framework).and_return("hybrid")

      expect(described_class.detect_test_framework).to eq("hybrid")
    end
  end

  describe ".default_pattern_for" do
    it "covers spec files for rspec" do
      expect(described_class.default_pattern_for("rspec")).to eq("spec/**/*_spec.rb")
    end

    it "covers test files for minitest" do
      expect(described_class.default_pattern_for("minitest")).to eq("test/**/*_test.rb")
    end

    it "covers both for hybrid" do
      expect(described_class.default_pattern_for("hybrid")).to eq("spec/**/*_spec.rb,test/**/*_test.rb")
    end

    it "raises for an unknown framework" do
      expect { described_class.default_pattern_for("rspec3") }.to raise_error(ArgumentError)
    end
  end

  describe ".subprocess_env" do
    it "flags the run as cable generation" do
      expect(described_class.subprocess_env).to include("ASYNCAPI_CABLE_GENERATING" => "true")
    end

    it "also sets openapi-ruby's flag, so host test-helper guards fire" do
      expect(described_class.subprocess_env).to include("OPENAPI_RUBY_GENERATING" => "true")
    end

    it "keeps the host environment openapi-ruby detected" do
      expect(described_class.subprocess_env.keys).to include("RAILS_ENV")
    end
  end

  describe ".generate_script" do
    subject(:script) { described_class.generate_script("hybrid", "spec/**/*_spec.rb,test/**/*_test.rb") }

    it "runs the generator through Runner" do
      expect(script).to include("AsyncapiCable::Generator::Runner.call")
    end

    it "passes the framework and pattern through" do
      expect(script).to include('framework: "hybrid"')
      expect(script).to include('pattern: "spec/**/*_spec.rb,test/**/*_test.rb"')
    end

    it "is valid Ruby" do
      expect { RubyVM::InstructionSequence.compile(script) }.not_to raise_error
    end

    it "raises for an unknown framework" do
      expect { described_class.generate_script("minispec", "spec/**/*_spec.rb") }
        .to raise_error(ArgumentError)
    end
  end
end

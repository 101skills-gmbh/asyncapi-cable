require "spec_helper"
require "asyncapi_cable/generator/runner"

RSpec.describe AsyncapiCable::Generator::Runner do
  let(:loader) { AsyncapiCable::Generator::DeclarationLoader }
  let(:writer) { AsyncapiCable::Generator::AsyncapiWriter }
  let(:io) { StringIO.new }

  it "writes every configured document and reports where it went" do
    allow(loader).to receive(:load!).and_return(["spec/asyncapi/a_spec.rb"])
    allow(writer).to receive(:generate_all!).and_return({cable_internal: "asyncapi/cable_internal.yaml"})

    described_class.call(framework: "rspec", pattern: "spec/asyncapi/**/*_spec.rb", io: io)

    expect(io.string).to include("Wrote AsyncAPI document cable_internal → asyncapi/cable_internal.yaml")
  end

  it "refuses to write when no declaration file matched" do
    allow(loader).to receive(:load!).and_return([])
    expect(writer).not_to receive(:generate_all!)

    expect { described_class.call(framework: "hybrid", pattern: "spec/typo/**/*_spec.rb", io: io) }
      .to raise_error(AsyncapiCable::Error, /no declaration files matched/)
  end
end

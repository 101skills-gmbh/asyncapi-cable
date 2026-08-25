require "spec_helper"

RSpec.describe AsyncapiCable::Diagnostics do
  let(:root_object_error) do
    [{"data_pointer" => "", "type" => "object", "error" => "value at root is not an object"}]
  end

  describe ".hint_for" do
    it "explains a payload that was serialized a layer too early" do
      expect(described_class.hint_for('{"a":1}', root_object_error))
        .to include("JSON string rather than an object")
    end

    it "says nothing for a Hash that simply does not match" do
      expect(described_class.hint_for({"a" => 1}, root_object_error)).to be_nil
    end

    it "says nothing for a string that is not JSON" do
      expect(described_class.hint_for("just text", root_object_error)).to be_nil
    end

    it "says nothing for a scalar encoded as JSON" do
      expect(described_class.hint_for("42", root_object_error)).to be_nil
    end

    # A contentSchema message is a JSON string on purpose; when one fails it
    # fails inside the described shape, not on the root type.
    it "says nothing when the failure is not the root type" do
      errors = [{"data_pointer" => "/payload", "type" => "string", "error" => "value at `/payload` is not a string"}]

      expect(described_class.hint_for('{"a":1}', errors)).to be_nil
    end

    it "says nothing without a payload to inspect" do
      expect(described_class.hint_for(nil, root_object_error)).to be_nil
    end
  end
end

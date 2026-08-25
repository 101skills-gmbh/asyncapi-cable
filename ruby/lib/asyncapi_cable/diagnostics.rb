require "json"

module AsyncapiCable
  # Explanations for validation failures whose cause is not what the failure
  # says. Only the wording changes — a payload that fails still fails.
  module Diagnostics
    DOUBLE_ENCODED = <<~TEXT.chomp
      The payload is a JSON string rather than an object. A broadcast site
      passing already-serialized JSON (`to_json`, or a renderer that returns a
      String) leaves ActionCable to encode it a second time, so the wire
      carries a JSON string literal and the client has to parse twice.
      Broadcast a Hash, or describe the string with `contentMediaType` and
      `contentSchema`.
    TEXT

    module_function

    # A String payload alone proves nothing: `contentSchema` describes an
    # embedded representation on purpose, and such a message validates. This
    # fires only when a schema wanted an object or array at the root and got a
    # string that happens to parse as one — the signature of a payload
    # serialized a layer too early.
    def hint_for(payload, errors)
      return nil unless serialized_container?(payload)
      return nil unless root_container_expected?(errors)

      DOUBLE_ENCODED
    end

    def serialized_container?(payload)
      return false unless payload.is_a?(String)

      parsed = JSON.parse(payload)
      parsed.is_a?(Hash) || parsed.is_a?(Array)
    rescue JSON::ParserError
      false
    end

    def root_container_expected?(errors)
      errors.any? do |error|
        error["data_pointer"].to_s.empty? && %w[object array].include?(error["type"])
      end
    end
  end
end

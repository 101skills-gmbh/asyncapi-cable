require "json_schemer"

module AsyncapiCable
  module Runtime
    class PayloadValidator
      class << self
        def instance
          @instance ||= new
        end

        def reset!
          @instance = nil
        end
      end

      # Validates `payload` against `#/components/schemas/<schema_name>` of
      # the passed-in `components` hash (sourced from the committed YAML, not
      # the live component registry — see exec-plan D4). The JSONSchemer
      # document is memoized per `components` object so repeated broadcasts on
      # the same contract reuse one compiled schema.
      def validate(payload, schema_name, components)
        normalized = stringify_keys(payload)
        ref = "#/components/schemas/#{schema_name}"
        schemer_for(components).ref(ref).validate(normalized).to_a
      end

      private

      def schemer_for(components)
        @schemers ||= {}
        @schemers[components.object_id] ||= JSONSchemer.schema(
          {"components" => {"schemas" => components["schemas"] || {}}}
        )
      end

      def stringify_keys(value)
        case value
        when Hash
          value.each_with_object({}) { |(k, v), h| h[k.to_s] = stringify_keys(v) }
        when Array
          value.map { |v| stringify_keys(v) }
        else
          value
        end
      end
    end
  end
end

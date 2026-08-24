require "yaml"

module AsyncapiCable
  module Core
    class Document
      ASYNCAPI_VERSION = "3.0.0"

      attr_reader :data

      def initialize(info:, servers: {}, cable_components: {})
        @data = {
          "asyncapi" => ASYNCAPI_VERSION,
          "info" => deep_stringify(info),
          "channels" => {},
          "operations" => {},
          "components" => {
            "schemas" => deep_stringify(cable_components["schemas"] || {}),
            "messages" => {}
          }
        }
        @data["servers"] = deep_stringify(servers) unless servers.nil? || servers.empty?
      end

      def add_channel(channel_context)
        channel_name = channel_name_for(channel_context)
        channel_entry = {"address" => channel_context.stream_template}
        # The exact Rails channel class name, so a generated client can use it
        # as the ActionCable subscription identifier without re-deriving it.
        if (klass = channel_context.channel_class) && klass.name
          channel_entry["x-actioncable-channel"] = klass.name
        end
        channel_entry["parameters"] = parameters_for(channel_context)
        channel_entry["messages"] = {}
        channel_entry.delete("parameters") if channel_entry["parameters"].empty?

        channel_context.operations.each do |op|
          next unless op.kind == :broadcast || op.kind == :publish

          op.messages.each do |component_class|
            message_name = component_class.component_name
            channel_entry["messages"][message_name] = {
              "$ref" => "#/components/messages/#{message_name}"
            }
            add_message_component(component_class)
          end

          add_operation(channel_name, op)
        end

        @data["channels"][channel_name] = channel_entry
      end

      def to_h
        result = @data.dup
        result["channels"] = sort_hash(result["channels"])
        result["operations"] = sort_hash(result["operations"])
        result["components"] = result["components"].transform_values { |v| sort_hash(v) }
        result.delete("components") if result["components"].values.all?(&:empty?)
        result
      end

      def to_yaml = to_h.to_yaml

      def to_json(*_args)
        require "json"
        JSON.pretty_generate(to_h)
      end

      private

      def channel_name_for(channel_context)
        klass = channel_context.channel_class
        return channel_context.stream_template if klass.nil? || klass.name.nil?

        klass.name.demodulize.sub(/Channel\z/, "")
      end

      # AsyncAPI 3.0 Parameter Objects are string-only: they carry no `schema`,
      # only `enum`/`default`/`examples`/`description`. Map the declared schema's
      # constraints onto those fields and drop the schema itself, otherwise the
      # document fails 3.0 validation.
      def parameters_for(channel_context)
        channel_context.parameters.each_with_object({}) do |param, acc|
          entry = {}
          entry["description"] = param[:description] if param[:description]
          if (schema = param[:schema])
            entry["enum"] = deep_stringify(schema[:enum]) if schema[:enum]
            entry["default"] = schema[:default] if schema.key?(:default)
            entry["examples"] = deep_stringify(schema[:examples]) if schema[:examples]
          end
          # Server-derived params are not passed by the client at subscribe time.
          entry["x-client-supplied"] = false if param[:client_supplied] == false
          acc[param[:name]] = entry
        end
      end

      def add_operation(channel_name, op)
        op_id = op.operation_id || default_operation_id(channel_name, op)
        action = (op.kind == :broadcast) ? "receive" : "send"
        message_refs = op.messages.map do |klass|
          {"$ref" => "#/channels/#{channel_name}/messages/#{klass.component_name}"}
        end

        @data["operations"][op_id] = {
          "action" => action,
          "channel" => {"$ref" => "#/channels/#{channel_name}"},
          "messages" => message_refs
        }
        @data["operations"][op_id]["summary"] = op.summary if op.summary
      end

      def default_operation_id(channel_name, op)
        "#{op.kind}#{channel_name}"
      end

      def add_message_component(component_class)
        name = component_class.component_name
        @data["components"]["messages"][name] ||= {
          "payload" => {"$ref" => "#/components/schemas/#{name}"}
        }
      end

      def deep_stringify(value)
        case value
        when Hash then value.each_with_object({}) { |(k, v), h| h[k.to_s] = deep_stringify(v) }
        when Array then value.map { |v| deep_stringify(v) }
        when Symbol then value.to_s
        else value
        end
      end

      def sort_hash(hash)
        hash.sort.to_h
      end
    end
  end
end

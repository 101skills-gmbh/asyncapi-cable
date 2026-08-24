require "yaml"
require "pathname"

module AsyncapiCable
  module Runtime
    # Runtime source of truth for broadcast validation: the committed
    # `asyncapi/<schema>.yaml` artifacts, parsed and memoized. This is the
    # read side of the contract; the write side (RSpec specs ->
    # MetadataStore -> AsyncapiWriter) is untouched and remains the
    # authoring path. See docs/exec-plans/asyncapi-cable-runtime-validation.md (D1).
    class ContractRegistry
      Match = Struct.new(:matcher, :schema_names, :components)

      class << self
        def instance
          @instance ||= new
        end

        def reset!
          @instance = nil
        end

        def broadcast_schemas_for(stream) = instance.broadcast_schemas_for(stream)
      end

      def broadcast_schemas_for(stream)
        channels.select { |match| match.matcher.match?(stream) }
      end

      def channels
        @channels ||= load_channels
      end

      private

      def load_channels
        result = AsyncapiCable.configuration.schemas.keys.flat_map do |schema_name|
          doc = load_document(schema_name)
          doc ? channels_from(doc) : []
        end
        log_load(result.size)
        result
      end

      def channels_from(doc)
        operations = doc["operations"] || {}
        components = doc["components"] || {}

        operations.filter_map do |_op_id, op|
          next unless op["action"] == "receive"

          channel = resolve(doc, op.dig("channel", "$ref"))
          address = channel && channel["address"]
          next unless address

          schema_names = Array(op["messages"]).filter_map do |msg_ref|
            schema_name_for(doc, msg_ref["$ref"])
          end.uniq

          Match.new(
            matcher: StreamMatcher.new(address),
            schema_names: schema_names,
            components: components
          )
        end
      end

      # Walks #/channels/<Ch>/messages/<Key> -> #/components/messages/<M>
      # -> payload.$ref -> #/components/schemas/<Schema>, returning <Schema>.
      def schema_name_for(doc, channel_message_ref)
        channel_message = resolve(doc, channel_message_ref)
        message = channel_message && resolve(doc, channel_message["$ref"])
        payload_ref = message&.dig("payload", "$ref")
        payload_ref&.split("/")&.last
      end

      def resolve(doc, ref)
        return nil unless ref.is_a?(String) && ref.start_with?("#/")
        doc.dig(*ref.delete_prefix("#/").split("/"))
      end

      def load_document(schema_name)
        path = schema_path(schema_name)
        return nil unless path.exist?

        contents = path.read
        return nil if contents.strip.empty?

        YAML.safe_load(contents)
      rescue => e
        logger.warn("[AsyncapiCable] failed to load contract #{path}: #{e.message}")
        nil
      end

      def schema_path(schema_name)
        ext = (AsyncapiCable.configuration.schema_output_format.to_sym == :json) ? "json" : "yaml"
        schema_dir.join("#{schema_name}.#{ext}")
      end

      def schema_dir
        dir = AsyncapiCable.configuration.schema_output_dir.to_s
        pathname = Pathname.new(dir)
        return pathname if pathname.absolute?

        if defined?(::Rails) && ::Rails.respond_to?(:root) && ::Rails.root
          ::Rails.root.join(dir)
        else
          pathname
        end
      end

      def log_load(count)
        if count.zero?
          logger.warn(
            "[AsyncapiCable] contract registry loaded 0 channels; runtime broadcast " \
            "validation is a no-op — check schema_output_dir (#{schema_dir}) and that the " \
            "asyncapi contract files exist"
          )
        else
          logger.info("[AsyncapiCable] contract registry loaded #{count} channel(s)")
        end
      end

      def logger
        AsyncapiCable::Runtime.logger
      end
    end
  end
end

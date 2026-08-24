module AsyncapiCable
  module Dsl
    class ChannelContext
      attr_reader :stream_template, :parameters, :operations, :channel_class, :schema_name

      def initialize(stream_template, channel_class: nil, schema_name: nil)
        @stream_template = stream_template
        @channel_class = channel_class
        @schema_name = schema_name
        @parameters = []
        @operations = []
      end

      # `client_supplied: false` marks an address parameter the server derives
      # (e.g. from the session) rather than one the client passes at subscribe
      # time — the generated client omits it from the channel's params.
      def parameter(name, schema: nil, description: nil, client_supplied: true)
        @parameters << {
          name: name.to_s,
          schema: schema,
          description: description,
          client_supplied: client_supplied
        }.compact
      end

      def subscribe(summary = nil, &block)
        add_operation(:subscribe, summary, &block)
      end

      def broadcast(summary = nil, &block)
        add_operation(:broadcast, summary, &block)
      end

      def publish(summary = nil, &block)
        add_operation(:publish, summary, &block)
      end

      private

      def add_operation(kind, summary, &block)
        op = OperationContext.new(kind, summary)
        op.instance_eval(&block) if block
        @operations << op
        op
      end
    end
  end
end

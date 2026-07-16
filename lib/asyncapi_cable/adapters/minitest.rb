require "asyncapi_cable"
require "asyncapi_cable/testing/assert_helpers"
require "active_support/core_ext/class/attribute"

module AsyncapiCable
  module Adapters
    module Minitest
      module DSL
        include Testing::AssertHelpers

        def self.included(base)
          base.extend ClassMethods
          base.class_attribute :_asyncapi_schema_name, default: nil
          base.class_attribute :_asyncapi_contexts, default: []
        end

        module ClassMethods
          def asyncapi_schema(name)
            self._asyncapi_schema_name = name.to_sym
          end

          def channel(stream_template, channel_class: nil, &block)
            context = Dsl::ChannelContext.new(
              stream_template,
              channel_class: channel_class,
              schema_name: _asyncapi_schema_name
            )
            context.instance_eval(&block) if block
            self._asyncapi_contexts = _asyncapi_contexts + [context]
            Dsl::MetadataStore.register(context)
            context
          end
        end

        private

        def asyncapi_declared_contexts
          self.class._asyncapi_contexts
        end

        def asyncapi_flunk(message)
          flunk(message)
        end
      end

      def self.install!
        # Intentional no-op — mirrors openapi-ruby's Minitest adapter.
        # Hosts opt in by including AsyncapiCable::Adapters::Minitest::DSL
        # into their base test class (e.g. ActiveSupport::TestCase).
      end
    end
  end
end

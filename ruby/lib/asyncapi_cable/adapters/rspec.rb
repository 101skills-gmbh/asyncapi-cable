require "asyncapi_cable"
require "asyncapi_cable/testing/assert_helpers"

module AsyncapiCable
  module Adapters
    module RSpec
      # Class-level DSL extended onto :asyncapi example groups. Mirrors
      # openapi-ruby's Minitest-style `api_path`: `channel` registers the
      # declaration flat and opens no nested example groups; examples are
      # plain `it` blocks calling assert_asyncapi_broadcast.
      module ExampleGroupHelpers
        def asyncapi_schema(name)
          metadata[:asyncapi_schema_name] = name.to_sym
        end

        def channel(stream_template, channel_class: nil, &block)
          context = Dsl::ChannelContext.new(
            stream_template,
            channel_class: channel_class || described_class,
            schema_name: metadata[:asyncapi_schema_name]
          )
          context.instance_eval(&block) if block
          metadata[:asyncapi_contexts] ||= []
          metadata[:asyncapi_contexts] << context
          Dsl::MetadataStore.register(context)
          context
        end
      end

      # Instance-level helpers mixed into :asyncapi examples.
      module ExampleHelpers
        include Testing::AssertHelpers

        private

        def asyncapi_declared_contexts
          meta = ::RSpec.current_example.metadata
          while meta
            return meta[:asyncapi_contexts] if meta[:asyncapi_contexts]
            meta = meta[:parent_example_group] || meta[:example_group]
          end
          []
        end

        def asyncapi_flunk(message)
          raise message
        end
      end

      def self.install!
        ::RSpec.configure do |config|
          config.extend ExampleGroupHelpers, type: :asyncapi
          config.include ExampleHelpers, type: :asyncapi
        end
      end
    end
  end
end

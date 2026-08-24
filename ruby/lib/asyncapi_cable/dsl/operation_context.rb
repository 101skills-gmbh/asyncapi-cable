module AsyncapiCable
  module Dsl
    class OperationContext
      KINDS = %i[subscribe broadcast publish].freeze

      attr_reader :kind, :summary, :messages
      attr_accessor :operation_id

      def initialize(kind, summary = nil)
        unless KINDS.include?(kind)
          raise ArgumentError, "operation kind must be one of #{KINDS.inspect}, got #{kind.inspect}"
        end
        @kind = kind
        @summary = summary
        @messages = []
        @operation_id = nil
      end

      def message(component_class)
        unless component_class.is_a?(Class) && component_class < OpenapiRuby::Components::Base
          raise ArgumentError, "message must be an OpenapiRuby::Components::Base subclass, got #{component_class.inspect}"
        end
        @messages << component_class
        component_class
      end

      def operationId(value)
        @operation_id = value
      end
    end
  end
end

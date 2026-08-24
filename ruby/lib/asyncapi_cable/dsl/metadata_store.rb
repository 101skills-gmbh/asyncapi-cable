module AsyncapiCable
  module Dsl
    class MetadataStore
      class << self
        def instance
          @instance ||= new
        end

        def register(context) = instance.register(context)

        def contexts_for(schema_name) = instance.contexts_for(schema_name)

        def all_contexts = instance.all_contexts

        def clear!(scope: nil) = instance.clear!(scope: scope)
      end

      def initialize
        @contexts = []
      end

      def register(context)
        @contexts << context
        context
      end

      def contexts_for(schema_name)
        schema_name = schema_name&.to_sym
        @contexts.select { |c| c.schema_name.nil? || c.schema_name.to_sym == schema_name }
      end

      def all_contexts
        @contexts.dup
      end

      def clear!(scope: nil)
        if scope
          target = scope.to_sym
          @contexts.reject! { |c| c.schema_name && c.schema_name.to_sym == target }
        else
          @contexts = []
        end
      end
    end
  end
end

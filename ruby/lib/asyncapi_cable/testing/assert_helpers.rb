require "json"

module AsyncapiCable
  module Testing
    # Shared core of assert_asyncapi_broadcast. Adapters mix this in and
    # supply two hooks: #asyncapi_declared_contexts (the channel contexts
    # declared on the test class / example group) and #asyncapi_flunk
    # (framework-native test failure).
    #
    # Usage errors (undeclared broadcast operation, unresolved template
    # params, non-test cable adapter) raise AsyncapiCable::Error; only
    # genuine test failures go through asyncapi_flunk.
    module AssertHelpers
      def assert_asyncapi_broadcast(params: {}, &trigger)
        raise Error, "assert_asyncapi_broadcast requires a block that triggers the broadcast" unless trigger

        context = asyncapi_find_broadcast_context!(asyncapi_declared_contexts, params)
        stream = asyncapi_expand_stream!(context.stream_template, params)
        payloads = asyncapi_capture_broadcasts(stream, &trigger)

        if payloads.empty?
          asyncapi_flunk("Expected at least one broadcast on #{stream.inspect}, but none was captured")
        end

        payloads.each do |payload|
          errors = asyncapi_broadcast_errors(context, payload)
          next if errors.empty?

          asyncapi_flunk(
            "AsyncAPI broadcast validation failed for #{stream.inspect}:\n  #{asyncapi_error_summary(errors)}"
          )
        end

        payloads
      end

      # Declared message schemas may `$ref` sibling components — an enum, or a
      # REST component an embedded payload points at — so the validation
      # document carries every registry class sharing the messages' scopes
      # plus the transitive closure of what those reference. The message
      # classes are entry points in their own right, as they are for the
      # writer: one may well carry a scope no other component shares. That is
      # the same set AsyncapiWriter publishes, so a payload that validates here
      # validates against the committed document too. Memoized per scope set:
      # PayloadValidator caches one compiled schema per components object.
      #
      # `Loader#load!` runs first because it is what assigns inferred scopes:
      # reading `_component_scopes` before it has run yields an empty scope set
      # for every class, and with it an empty components object. It eager-loads
      # classes reachable only via `$ref` strings and is idempotent.
      def self.components_for(message_classes)
        OpenapiRuby::Components::Loader.new.load!

        scopes = message_classes.flat_map(&:_component_scopes).uniq.sort
        @components ||= {}
        @components[scopes] ||= begin
          scoped = OpenapiRuby::Components::Registry.instance.all_registered_classes.select { |klass|
            (klass._component_scopes & scopes).any?
          }
          schemas = Components::ReferenceClosure.expand((scoped + message_classes).uniq, scope: scopes)
            .to_h { |klass| [klass.component_name, klass._schema_definition] }
          {"schemas" => schemas}
        end
      end

      private

      def asyncapi_find_broadcast_context!(contexts, params)
        candidates = contexts.select { |ctx| ctx.operations.any? { |op| op.kind == :broadcast } }

        if candidates.empty?
          raise Error, "No channel with a broadcast operation is declared in this test class"
        end
        return candidates.first if candidates.size == 1

        keys = params.keys.map(&:to_s).sort
        scoped = candidates.select { |ctx| asyncapi_template_params(ctx.stream_template).sort == keys }
        return scoped.first if scoped.size == 1

        raise Error, "Ambiguous channel for params #{params.keys.inspect}: " \
          "#{candidates.size} declared channels have broadcast operations " \
          "(#{candidates.map { |c| c.stream_template.inspect }.join(", ")})"
      end

      def asyncapi_expand_stream!(template, params)
        missing = []
        stream = template.gsub(/\{(\w+)\}/) do
          name = ::Regexp.last_match(1)
          value = params[name.to_sym] || params[name]
          missing << name if value.nil?
          value.to_s
        end

        unless missing.empty?
          raise Error, "Missing params #{missing.inspect} to expand stream template #{template.inspect}"
        end

        stream
      end

      def asyncapi_capture_broadcasts(stream)
        pubsub = ::ActionCable.server.pubsub
        unless pubsub.respond_to?(:broadcasts)
          raise Error, "assert_asyncapi_broadcast requires the ActionCable test adapter " \
            "(set `adapter: test` for the test environment in config/cable.yml)"
        end

        seen = pubsub.broadcasts(stream).size
        yield
        pubsub.broadcasts(stream).drop(seen).map { |message| asyncapi_decode(message) }
      end

      # Validates against the *declared* message classes (the authoring
      # side), not the committed YAML the runtime ContractRegistry reads —
      # when a spec documents a new channel, the YAML doesn't exist yet.
      # Messages are alternatives per AsyncAPI 3: pass if any validates
      # clean, otherwise surface the closest match's errors.
      def asyncapi_broadcast_errors(context, payload)
        message_classes = context.operations
          .select { |op| op.kind == :broadcast }
          .flat_map(&:messages)
        return [] if message_classes.empty?

        components = AssertHelpers.components_for(message_classes)
        results = message_classes.map do |klass|
          Runtime::PayloadValidator.instance.validate(payload, klass.component_name, components)
        end
        return [] if results.any?(&:empty?)

        results.min_by(&:size) || []
      end

      def asyncapi_error_summary(errors)
        errors.map { |e| e["error"] }.compact.uniq.join("\n  ")
      end

      def asyncapi_template_params(template)
        template.scan(/\{(\w+)\}/).flatten
      end

      def asyncapi_decode(message)
        message.is_a?(String) ? JSON.parse(message) : message
      rescue JSON::ParserError
        message
      end
    end
  end
end

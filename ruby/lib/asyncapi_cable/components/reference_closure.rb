require "openapi_ruby"

module AsyncapiCable
  module Components
    # Expands a set of component classes to everything they `$ref`.
    #
    # Scope alone is not a sufficient filter for a document. A cable message
    # can legitimately reference a component that is not cable-scoped — the
    # presence channels embed a rendered REST representation, so the honest
    # contract says "this is an Item" and points at the REST component. Include
    # the referrer without the referee and the document carries a pointer that
    # resolves to nothing: `@asyncapi/parser` rejects the whole document with
    # `'#/components/schemas/X' does not exist`.
    #
    # So a document includes what its own scope selects, plus the transitive
    # closure of what those components reference. Scope stays the *entry point*
    # into the graph rather than a fence around it.
    module ReferenceClosure
      SCHEMA_REF = %r{\A#/components/schemas/(?<name>\w+)\z}

      module_function

      # Registry classes whose component_name a `$ref` can resolve to.
      def expand(classes, registry: OpenapiRuby::Components::Registry.instance.all_registered_classes)
        by_name = registry.to_h { |klass| [klass.component_name, klass] }
        included = {}
        queue = classes.to_a.dup

        until queue.empty?
          klass = queue.shift
          name = klass.component_name
          next if included.key?(name)

          included[name] = klass
          referenced_names(klass._schema_definition).each do |referenced|
            next if included.key?(referenced)

            referee = by_name[referenced]
            # An unresolvable name is left alone: the document then fails to
            # parse, which is the right outcome for a typo in a $ref.
            queue << referee if referee
          end
        end

        included.values
      end

      def referenced_names(node, found = [])
        case node
        when Hash
          node.each do |key, value|
            match = (key.to_s == "$ref") && value.is_a?(String) && SCHEMA_REF.match(value)
            if match
              found << match[:name]
            else
              referenced_names(value, found)
            end
          end
        when Array
          node.each { |element| referenced_names(element, found) }
        end

        found.uniq
      end
    end
  end
end

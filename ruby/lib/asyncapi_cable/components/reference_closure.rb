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

      # `scope` is the document's own scope (a symbol, or several in priority
      # order), consulted when the referring component cannot settle a name on
      # its own. The entry points' own scopes follow it: a document assembled
      # from `:v1` components resolves its pointers the way the `:v1` document
      # would, which is what makes the walk order-independent.
      def expand(classes, scope: nil, registry: OpenapiRuby::Components::Registry.instance.all_registered_classes)
        entry_points = classes.to_a
        candidates = registry.group_by(&:component_name)
        preferred = (Array(scope) + entry_points.flat_map(&:_component_scopes)).compact.uniq
        included = {}
        queue = entry_points.dup

        until queue.empty?
          klass = queue.shift
          name = klass.component_name
          next if included.key?(name)

          included[name] = klass
          referenced_names(klass._schema_definition).each do |referenced|
            next if included.key?(referenced)

            referee = resolve(referenced, candidates, referrer: klass, prefer: preferred)
            queue << referee if referee
          end
        end

        included.values
      end

      # A component_name is only unique within a scope: openapi-ruby documents
      # routinely carry a richer admin variant of a public resource under the
      # same name, and its own `to_openapi_hash` never meets the collision
      # because it filters by scope before indexing by name. A closure walk has
      # no such filter, so it has to say which variant a pointer meant.
      #
      # A `$ref` means what it means in the referring component's own document,
      # so a candidate sharing a scope with the referrer wins. A shared
      # component settles nothing on its own though — one carrying
      # `[:v1, :admin]` shares a scope with both variants of the name it
      # references — so the document's scopes are applied next, in priority
      # order, then openapi-ruby's specificity rule (scope-specific beats
      # multi-scope). Anything still undecided is a real ambiguity and says so
      # rather than picking by registration order.
      def resolve(name, candidates, referrer:, prefer: [])
        found = candidates[name]
        return nil if found.nil? || found.empty?
        return found.first if found.size == 1

        narrowed = narrow(found, referrer._component_scopes)
        prefer.each do |scope|
          break if narrowed.size == 1

          narrowed = narrow(narrowed, [scope])
        end
        narrowed = least_scoped(narrowed) if narrowed.size > 1
        return narrowed.first if narrowed.size == 1

        raise Error, ambiguity_message(name, referrer, narrowed)
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

      # Narrowing never empties the set: a scope no candidate carries tells us
      # nothing, so it leaves the decision to the next rule.
      def narrow(candidates, scopes)
        wanted = scopes.compact
        return candidates if wanted.empty?

        matching = candidates.select { |klass| (klass._component_scopes & wanted).any? }
        matching.empty? ? candidates : matching
      end

      def least_scoped(candidates)
        fewest = candidates.map { |klass| klass._component_scopes.size }.min
        candidates.select { |klass| klass._component_scopes.size == fewest }
      end

      def ambiguity_message(name, referrer, candidates)
        listed = candidates.map { |klass| "#{klass.name} #{klass._component_scopes.inspect}" }.join(", ")
        "Ambiguous $ref #/components/schemas/#{name} from #{referrer.name}: #{listed}. " \
          "Give the intended component a scope the referrer shares, or name the variants distinctly."
      end
    end
  end
end

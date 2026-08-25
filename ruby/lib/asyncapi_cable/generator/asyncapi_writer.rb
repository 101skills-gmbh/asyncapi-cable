require "fileutils"

module AsyncapiCable
  module Generator
    class AsyncapiWriter
      class << self
        def generate_all!(output_dir: nil, format: nil)
          configuration = AsyncapiCable.configuration
          output_dir ||= configuration.schema_output_dir
          format ||= configuration.schema_output_format

          raise Error, "AsyncapiCable.configuration.schemas is empty" if configuration.schemas.empty?

          configuration.schemas.map do |schema_name, schema_config|
            document = build_document(schema_name, schema_config)
            path = write(document, schema_name, output_dir: output_dir, format: format)
            [schema_name, path]
          end.to_h
        end

        def build_document(schema_name, schema_config)
          scope = (schema_config[:component_scope] || schema_config["component_scope"] || :cable).to_sym
          components = load_cable_components(scope)

          document = Core::Document.new(
            info: schema_config[:info] || schema_config["info"] || {},
            servers: schema_config[:servers] || schema_config["servers"] || {},
            cable_components: components
          )

          Dsl::MetadataStore.contexts_for(schema_name).each do |context|
            document.add_channel(context)
          end

          document
        end

        # Bypass OpenapiRuby::Components::Loader#to_openapi_hash and read raw
        # schema definitions directly. The host's openapi-ruby is configured
        # with `camelize_keys = true` which is correct for REST API docs but
        # wrong for cable AsyncAPI docs whose payloads are the snake_case
        # wire format `BroadcastingConcern` actually emits. The runtime
        # PayloadValidator already does the same bypass for the same reason.
        #
        # We still need the Loader's eager-load side effect though: component
        # classes reachable only via `$ref` strings (e.g. an enum a message
        # schema refs) aren't autoloaded by Ruby, so a raw registry scan
        # would miss them. `Loader#load!` is idempotent.
        #
        # Scope selects the entry points; ReferenceClosure adds what those
        # components reference, whatever scope the referee carries.
        def load_cable_components(scope)
          OpenapiRuby::Components::Loader.new.load!

          scoped = OpenapiRuby::Components::Registry.instance.all_registered_classes.select do |klass|
            klass._component_scopes.include?(scope)
          end
          schemas = Components::ReferenceClosure.expand(scoped).each_with_object({}) do |klass, acc|
            acc[klass.component_name] = klass._schema_definition
          end
          {"schemas" => schemas}
        end

        def write(document, schema_name, output_dir:, format:)
          ext = (format.to_sym == :json) ? "json" : "yaml"
          path = File.join(output_dir, "#{schema_name}.#{ext}")
          FileUtils.mkdir_p(File.dirname(path))
          contents = (ext == "json") ? document.to_json : document.to_yaml
          File.write(path, contents)
          path
        end
      end
    end
  end
end

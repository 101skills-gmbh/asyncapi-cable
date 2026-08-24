require "asyncapi_cable/version"
require "asyncapi_cable/configuration"
require "asyncapi_cable/dsl/metadata_store"
require "asyncapi_cable/dsl/operation_context"
require "asyncapi_cable/dsl/channel_context"
require "asyncapi_cable/core/document"
require "asyncapi_cable/generator/asyncapi_writer"
require "asyncapi_cable/runtime/stream_matcher"
require "asyncapi_cable/runtime/payload_validator"
require "asyncapi_cable/runtime/contract_registry"
require "asyncapi_cable/runtime/channel_hook"
require "asyncapi_cable/engine"

module AsyncapiCable
  class Error < StandardError; end

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield configuration
    end

    def reset_configuration!
      @configuration = Configuration.new
    end

    # True when the current process was started by `asyncapi_cable:generate`
    # (the rake task sets ASYNCAPI_CABLE_GENERATING=true in the subprocess).
    #
    # Such a run loads declaration files for their `channel` blocks and never
    # executes them, so a host test helper can skip its test-time setup:
    #
    #   unless AsyncapiCable.schema_generating?
    #     require "rails/test_help"
    #   end
    #
    # Cable generation also sets openapi-ruby's OPENAPI_RUBY_GENERATING, so a
    # helper already guarding on `OpenapiRuby.schema_generating?` needs no
    # second guard.
    def schema_generating?
      ENV["ASYNCAPI_CABLE_GENERATING"] == "true"
    end
  end
end

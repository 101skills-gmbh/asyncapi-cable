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
  end
end

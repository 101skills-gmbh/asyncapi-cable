module AsyncapiCable
  class Configuration
    attr_accessor :schemas, :schema_output_dir, :schema_output_format
    attr_reader :validation_mode

    VALIDATION_MODES = %i[disabled warn_only enabled].freeze

    def initialize
      @schemas = {}
      @validation_mode = :disabled
      @schema_output_dir = "asyncapi"
      @schema_output_format = :yaml
    end

    def validation_mode=(mode)
      unless VALIDATION_MODES.include?(mode)
        raise ArgumentError, "validation_mode must be one of #{VALIDATION_MODES.inspect}, got #{mode.inspect}"
      end
      @validation_mode = mode
    end
  end
end

module AsyncapiCable
  module Runtime
    module ChannelHook
      def broadcast(stream, payload, *args, **kwargs)
        Runtime.validate_broadcast!(stream, payload)
        super
      end
    end

    def self.validate_broadcast!(stream, payload)
      mode = AsyncapiCable.configuration.validation_mode
      return if mode == :disabled

      matches = ContractRegistry.broadcast_schemas_for(stream)
      return if matches.empty?

      errors = collect_errors(matches, payload)
      return if errors.empty?

      report(mode, stream, errors, payload)
    end

    # AsyncAPI 3 treats a channel's messages as alternatives: a payload
    # matching ANY declared message satisfies the channel. We validate
    # against every candidate schema across all matching channels, pass if
    # any validates clean, and otherwise surface the closest match's errors
    # (fewest failures).
    def self.collect_errors(matches, payload)
      results = matches.flat_map do |match|
        match.schema_names.map do |schema_name|
          PayloadValidator.instance.validate(payload, schema_name, match.components)
        end
      end

      return [] if results.empty?
      return [] if results.any?(&:empty?)

      results.min_by(&:size)
    end

    def self.report(mode, stream, errors, payload = nil)
      summary = errors.map { |e| e["error"] }.compact.uniq.join("; ")
      message = "AsyncAPI broadcast validation failed for stream #{stream.inspect}: #{summary}"
      if (hint = Diagnostics.hint_for(payload, errors))
        message = "#{message}\n#{hint}"
      end

      case mode
      when :warn_only
        logger.warn(message)
      when :enabled
        raise Error, message
      end
    end

    def self.logger
      if defined?(::Rails) && ::Rails.respond_to?(:logger) && ::Rails.logger
        ::Rails.logger
      else
        @fallback_logger ||= Logger.new($stdout)
      end
    end
  end
end

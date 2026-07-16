module AsyncapiCable
  module Runtime
    class StreamMatcher
      def initialize(template)
        @template = template.to_s
        @regex = build_regex(@template)
      end

      def match?(stream)
        return false if @regex.nil?
        !@regex.match(stream.to_s).nil?
      end

      private

      def build_regex(template)
        return nil if template.empty?

        escaped = Regexp.escape(template).gsub(/\\\{(\w+)\\\}/) { "(?<#{$1}>[^/]+?)" }
        Regexp.new("\\A#{escaped}\\z")
      end
    end
  end
end

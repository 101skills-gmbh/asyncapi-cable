require "asyncapi_cable"
require "asyncapi_cable/generator/declaration_loader"

module AsyncapiCable
  module Generator
    # The body of the generation subprocess: load the declarations, then write
    # every configured document.
    module Runner
      module_function

      def call(framework:, pattern:, io: $stdout)
        loaded = DeclarationLoader.load!(framework: framework, pattern: pattern)

        if loaded.empty?
          # Writing now would replace the committed documents with channel-less
          # ones, and a `git diff` gate over the output would still be clean if
          # the host has no committed documents yet.
          raise Error, "no declaration files matched PATTERN=#{pattern.inspect} (framework: #{framework})"
        end

        AsyncapiWriter.generate_all!.each do |name, path|
          io.puts "Wrote AsyncAPI document #{name} → #{path}"
        end
      end
    end
  end
end

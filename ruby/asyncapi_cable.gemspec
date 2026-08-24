require_relative "lib/asyncapi_cable/version"

Gem::Specification.new do |spec|
  spec.name = "asyncapi_cable"
  spec.version = AsyncapiCable::VERSION
  spec.authors = ["Fobizz"]
  spec.email = ["dev@fobizz.com"]
  spec.homepage = "https://github.com/fobizz/asyncapi_cable"
  spec.summary = "AsyncAPI 3 documentation and runtime validation for Rails ActionCable channels."
  spec.description = <<~DESC
    AsyncAPI Cable adds an AsyncAPI 3 DSL on top of Rails ActionCable.
    It generates an AsyncAPI document for your channels, sharing JSON
    Schema components with OpenAPI tooling, and validates broadcast and
    transmit payloads against declared message schemas at runtime.
  DESC
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.3.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.add_dependency "actioncable", ">= 7.1"
  spec.add_dependency "activesupport", ">= 7.1"
  spec.add_dependency "json_schemer", ">= 2.3"
  # 4.0.3 is the first release whose generator suppressors this engine reuses.
  spec.add_dependency "openapi-ruby", ">= 4.0.3"
  spec.add_dependency "railties", ">= 7.1"
end

namespace :asyncapi_cable do
  desc "Generate AsyncAPI 3 documents for ActionCable channels. PATTERN= comma-separated globs of spec files to load before generation."
  task generate: :environment do
    require "rspec/core"
    require "asyncapi_cable/adapters/rspec"
    AsyncapiCable::Adapters::RSpec.install!

    spec_dir = File.expand_path("spec")
    $LOAD_PATH.unshift(spec_dir) unless $LOAD_PATH.include?(spec_dir)

    pattern = ENV.fetch("PATTERN", "spec/**/*_spec.rb, packs/*/spec/**/*_spec.rb")
    files = pattern.split(",").map(&:strip).flat_map { |g| Dir.glob(g) }.sort.uniq

    if files.empty?
      warn "asyncapi_cable:generate — no spec files matched PATTERN=#{pattern.inspect}"
      next
    end

    files.each { |f| require File.expand_path(f) }

    written = AsyncapiCable::Generator::AsyncapiWriter.generate_all!
    written.each do |name, path|
      puts "Wrote AsyncAPI document #{name} → #{path}"
    end
  end
end

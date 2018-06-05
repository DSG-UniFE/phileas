# frozen_string_literal: true

lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "phileas/version"

Gem::Specification.new do |spec|
  spec.name          = "phileas"
  spec.version       = Phileas::VERSION
  spec.authors       = ["Mauro Tortonesi", "Filippo Poltronieri"]
  spec.email         = ["mauro.tortonesi@unife.it", "filippo.poltronieri@unife.it"]

  spec.summary       = %q{A classy and adventurous Fog Computing simulator}
  spec.description   = %q{A classy and adventurous Fog Computing simulator}
  spec.homepage      = "https://github.com/DSG-UniFE/phileas"
  spec.license       = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the "allowed_push_host"
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.required_ruby_version = ">= 2.3.0"

  spec.add_dependency "as-duration", "~> 0.1.0"
  spec.add_dependency "erv", ">= 0.3.4"
  spec.add_dependency "geo_coord", "~> 0.1.0"

  spec.add_development_dependency "bundler", "~> 1.16"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "minitest", "~> 5.0"
end

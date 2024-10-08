# frozen_string_literal: true

lib = File.expand_path("lib", __dir__)

$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "dwca_hunter/version"

Gem::Specification.new do |gem|
  gem.required_ruby_version = ">= 3.3.0"
  gem.name          = "dwca_hunter"
  gem.version       = DwcaHunter.version
  gem.license       = "MIT"
  gem.authors       = ["Dmitry Mozzherin"]
  gem.email         = ["dmozzherin@gmail.com"]

  gem.summary       = "Converts a variety of available online resources to " \
                      "DarwinCore Archive files."
  gem.description   = "Gem harvests data from a variety of formats and " \
                      "converts incoming data to DwCA format."
  gem.homepage      = "https://github.com/GlobalNamesArchitecture/dwca_hunter"

  gem.files         = `git ls-files -z`.
                      split("\x0").
                      reject { |f| f.match(%r{^(test|spec|features)/}) }
  gem.bindir        = "exe"
  gem.executables   = gem.files.grep(%r{^exe/}) { |f| File.basename(f) }
  gem.require_paths = ["lib"]

  gem.add_dependency "base64", "~> 0.2"
  gem.add_dependency "biodiversity", "~> 6.0"
  gem.add_dependency "csv", "~> 3.3"
  gem.add_dependency "dwc-archive", "~> 1.1.9"
  gem.add_dependency "fiddle", "~> 1.1"
  gem.add_dependency "gn_uuid", "~> 0.5"
  gem.add_dependency "htmlentities", "~> 4.3"
  gem.add_dependency "nokogiri", "~> 1.16"
  gem.add_dependency "ostruct", "~> 0.6"
  gem.add_dependency "rest-client", "~> 2.1"
  gem.add_dependency "rubyzip", "~> 2.3"
  gem.add_dependency "thor", "~> 1.3"

  gem.add_development_dependency "bundler", "~> 2.5"
  gem.add_development_dependency "json", "~> 2.7.2"

  # gem.add_development_dependency "byebug", "~> 11.1"
  # gem.add_development_dependency "coveralls", "~> 0.8"
  gem.add_development_dependency "rake", "~> 13.2"
  gem.add_development_dependency "rspec", "~> 3.13"
  gem.add_development_dependency "rubocop", "~> 1.66"
  gem.add_development_dependency "ruby-lsp", "~> 0.17"
end

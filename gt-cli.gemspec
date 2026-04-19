require_relative "lib/gt/version"

Gem::Specification.new do |spec|
  spec.name          = "gt-cli"
  spec.version       = GT::VERSION
  spec.authors       = ["Jan Grodowski"]
  spec.email         = ["jgrodowski@gmail.com"]
  spec.summary       = "Lightweight CLI for managing stacked pull requests"
  spec.homepage      = "https://github.com/jgrodowski/gt"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.files         = Dir["lib/**/*.rb", "bin/*", "README.md", "LICENSE"]
  spec.bindir        = "bin"
  spec.executables   = ["gt"]

  spec.add_dependency "rake"
  spec.add_dependency "cli-ui", "~> 2.7"
end

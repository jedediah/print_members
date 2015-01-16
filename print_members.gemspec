# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'print_members/version'

Gem::Specification.new do |spec|
    spec.name = "print_members"
    spec.version = "0.3.4"
    spec.authors = ["Jedediah Smith"]
    spec.date = "2015-01-15"
    spec.description = "Pretty print a list of live methods and constants"
    spec.summary = spec.description
    spec.email = "jedediah@silencegreys.com"
    spec.extra_rdoc_files = ["README.rdoc"]
    spec.files = ["README.rdoc",
                  "print_members.gemspec",
                  "lib/print_members.rb",
                  "lib/print_members/extensions.rb",
                  "lib/print_members/librarian.rb",
                  "lib/print_members/active_record.rb",
                  "lib/print_members/analyzer.rb",
                  "lib/print_members/ansi.rb",
                  "lib/print_members/method.rb",
                  "Rakefile"]
    spec.has_rdoc = true
    spec.homepage = "http://github.com/jedediah/print_members"
    spec.require_paths = ["lib"]

    spec.add_development_dependency "bundler", "~> 1.7"
    spec.add_development_dependency "rake", "~> 10.0"

    # spec.name          = "gemtest"
    # spec.version       = Gemtest::VERSION
    # spec.authors       = ["TODO: Write your name"]
    # spec.email         = ["TODO: Write your email address"]
    # spec.summary       = %q{TODO: Write a short summary. Required.}
    # spec.description   = %q{TODO: Write a longer description. Optional.}
    # spec.homepage      = ""
    # spec.license       = "MIT"
    #
    # spec.files         = `git ls-files -z`.split("\x0")
    # spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
    # spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
    # spec.require_paths = ["lib"]
end

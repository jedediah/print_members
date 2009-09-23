Gem::Specification.new do |s|
  s.name = "print_members"
  s.version = "0.3.1"
  s.authors = ["Jedediah Smith"]
  s.date = "2009-06-10"
  s.description = "Pretty print a list of live methods and constants"
  s.summary = s.description
  s.email = "jedediah@silencegreys.com"
  s.extra_rdoc_files = ["README.rdoc"]
  s.files = ["README.rdoc",
             "print_members.gemspec",
             "lib/print_members.rb",
             "lib/print_members/extensions.rb",
             "lib/print_members/librarian.rb",
             "lib/print_members/active_record.rb",
             "lib/print_members/analyzer.rb",
             "lib/print_members/ansi.rb",
             "lib/print_members/method.rb",
             "Rakefile"]
  s.has_rdoc = true
  s.homepage = "http://github.com/jedediah/print_members"
  s.require_paths = ["lib"]
end

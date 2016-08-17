Gem::Specification.new do |gem|
  gem.name          = "pugbot"
  gem.version       = "0.1.1"
  gem.authors       = ["Xzanth"]
  gem.description   = "Pug bot as cinch plugin"
  gem.summary       = "Cinch plugin for organising pick up games, designed"\
  " with the game Midair in mind"
  gem.homepage      = "https://github.com/Xzanth/pugbot"
  gem.license       = "GPL-3.0"
  gem.files         = `git ls-files`.split($INPUT_RECORD_SEPARATOR)
  gem.require_paths = ["lib"]
  gem.platform      = Gem::Platform::RUBY

  gem.add_dependency("cinch", "~> 2.3.2")
  gem.add_dependency("cinch-identify", "~> 1.7.0")
  gem.add_dependency("cinch-commands", "~> 0.1.1")

  gem.add_development_dependency "rubocop"
  gem.add_development_dependency "yard"
  gem.add_development_dependency "rspec"
  gem.add_development_dependency "rake"
  gem.add_development_dependency "codeclimate-test-reporter"
end

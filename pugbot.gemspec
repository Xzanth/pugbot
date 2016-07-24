Gem::Specification.new do |gem|
  gem.name        = "pugbot"
  gem.version     = "0.1.0"
  gem.authors     = ["Xzanth"]
  gem.description = "Pug bot as cinch plugin"
  gem.summary     = "Cinch plugin for organising pick up games, designed with"\
  " the game Midair in mind"
  gem.homepage    = "https://github.com/Xzanth/pugbot"
  gem.license     = "GPL-3.0"
  gem.platform    = Gem::Platform::RUBY

  gem.add_dependency("cinch", "~> 2.3.2")
  gem.add_dependency("timers", "~> 4.1.1")

  gem.add_development_dependency "rubocop"
  gem.add_development_dependency "yard"

  gem.files = [
    "LICENSE",
    "README.md",
    ".yardopts",
    ".rubocop.yml",
    "lib/**/*"
  ]
end

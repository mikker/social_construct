require_relative "lib/social_construct/version"

Gem::Specification.new do |spec|
  spec.name        = "social_construct"
  spec.version     = SocialConstruct::VERSION
  spec.authors     = [ "Mikkel Malmberg" ]
  spec.email       = [ "mikkel@brnbw.com" ]
  spec.homepage    = "https://github.com/brnbw/social_construct"
  spec.summary     = "Rails engine for generating social media preview cards"
  spec.description = "A flexible Rails engine for generating social media preview cards (Open Graph images) with built-in preview functionality"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.add_dependency "rails", ">= 7.0"
  spec.add_dependency "ferrum", ">= 0.13"
  spec.add_dependency "marcel", ">= 1.0"
end

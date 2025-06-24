require "social_construct/version"
require "social_construct/engine"

# Dependencies
require "ferrum"
require "marcel"

module SocialConstruct
  # Configuration for template paths and other settings
  mattr_accessor :template_path
  @@template_path = "social_cards"
end

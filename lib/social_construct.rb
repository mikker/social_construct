require "social_construct/version"
require "social_construct/engine"
require "social_construct/card_concerns"

module SocialConstruct
  # Configuration for template paths and other settings
  mattr_accessor :template_path
  @@template_path = "social_cards"
end

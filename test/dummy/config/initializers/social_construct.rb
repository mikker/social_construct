Rails.application.configure do
  # Configure the template path for social card views
  # Default: "social_cards"
  # config.social_construct.template_path = "social_cards"

  # Configure paths for social card previews
  # Default: ["test/social_cards/previews"]
  # config.social_construct.preview_paths = ["test/social_cards/previews"]

  # Enable social card previews
  # Default: true in development, false otherwise
  # config.social_construct.show_previews = Rails.env.development?

  # Enable debug logging for social card generation
  # Default: false
  # SocialConstruct::BaseCard.debug = true
end

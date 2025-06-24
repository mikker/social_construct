module SocialConstruct
  class Engine < ::Rails::Engine
    isolate_namespace SocialConstruct

    config.social_construct = ActiveSupport::OrderedOptions.new
    config.social_construct.template_path = "social_cards"

    # Ensure dependencies are loaded
    config.before_initialize do
      require "ferrum"
      require "marcel"
    end
  end
end

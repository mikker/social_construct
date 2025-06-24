module SocialConstruct
  class Engine < ::Rails::Engine
    isolate_namespace SocialConstruct

    config.social_construct = ActiveSupport::OrderedOptions.new
    config.social_construct.template_path = "social_cards"
    config.social_construct.preview_paths = []
    config.social_construct.show_previews = Rails.env.development?

    # Set default preview path after application initializes
    config.after_initialize do |app|
      if app.config.social_construct.preview_paths.empty?
        app.config.social_construct.preview_paths = [Rails.root.join("test/social_cards/previews")]
      end
    end
  end
end

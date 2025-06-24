module SocialConstruct
  class Engine < ::Rails::Engine
    isolate_namespace SocialConstruct

    config.generators do |g|
      g.test_framework :minitest
    end

    # Allow host app to configure template path
    config.social_construct = ActiveSupport::OrderedOptions.new
    config.social_construct.template_path = "social_cards"

    initializer("social_construct.assets.precompile") do |app|
      app.config.assets.paths << root.join("app/assets/stylesheets")
    end

    # Ensure controller concern is available
    config.eager_load_paths << root.join("app/controllers/concerns")
  end
end

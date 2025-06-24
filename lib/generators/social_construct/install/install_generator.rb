require "rails/generators/base"

module SocialConstruct
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Creates SocialConstruct initializer, base classes, and example files"

      def create_initializer_file
        template("social_construct.rb", "config/initializers/social_construct.rb")
      end

      def create_application_social_card
        template("application_social_card.rb", "app/social_cards/application_social_card.rb")
      end

      def create_example_social_card
        template("example_social_card.rb", "app/social_cards/example_social_card.rb")
      end

      def create_example_template
        template("example_social_card.html.erb", "app/views/social_cards/example_social_card.html.erb")
      end

      def create_social_cards_layout
        template("social_cards_layout.html.erb", "app/views/layouts/social_cards.html.erb")
      end

      def create_example_preview
        template("example_social_card_preview.rb", "app/social_cards/previews/example_social_card_preview.rb")
      end

      def add_route
        route_string = <<-RUBY

  # Social card previews (development only)
  if Rails.env.development?
    mount SocialConstruct::Engine, at: "/rails/social_cards"
  end
        RUBY

        route(route_string)
      end

      def display_post_install
        readme("POST_INSTALL") if behavior == :invoke
      end
    end
  end
end

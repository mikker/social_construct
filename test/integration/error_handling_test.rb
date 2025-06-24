require "test_helper"

class ErrorHandlingTest < ActionDispatch::IntegrationTest
  class BrokenCard < SocialConstruct::BaseCard
    def render
      raise "Rendering failed!"
    end
  end

  class MissingTemplateCard < SocialConstruct::BaseCard
    def template_name
      "nonexistent_template"
    end
  end

  class ErrorController < ActionController::Base
    include SocialConstruct::Controller

    def broken
      card = BrokenCard.new
      send_social_card(card)
    end

    def missing_template
      card = MissingTemplateCard.new
      send_social_card(card)
    end

    def nil_card
      send_social_card(nil)
    end
  end

  setup do
    Rails.application.routes.draw do
      get "/broken", to: "error_handling_test/error#broken"
      get "/missing_template", to: "error_handling_test/error#missing_template"
      get "/nil_card", to: "error_handling_test/error#nil_card"
      mount SocialConstruct::Engine => "/rails"
    end
  end

  teardown do
    Rails.application.reload_routes!
  end

  test("handles rendering errors gracefully with fallback PNG") do
    get "/broken"

    assert_response :success
    assert_equal "image/png", response.content_type
    # Should return a transparent PNG
    assert response.body.start_with?("\x89PNG")
  end

  test("handles missing template with error") do
    get "/missing_template"

    assert_response :success
    assert_equal "image/png", response.content_type
    # Falls back to transparent PNG
    assert response.body.start_with?("\x89PNG")
  end

  test("handles nil card with fallback") do
    get "/nil_card"

    assert_response :success
    assert_equal "image/png", response.content_type
    assert response.body.start_with?("\x89PNG")
  end

  test("preview controller handles malformed preview class gracefully") do
    preview_dir = Rails.root.join("app/social_cards/previews")
    FileUtils.mkdir_p(preview_dir)

    # Create a preview file with syntax error
    File.write(
      preview_dir.join("bad_preview.rb"),
      <<~RUBY
        class BadPreview
          def example
            # Missing end statement
        end
      RUBY
    )

    # Try to load previews - should not crash
    get "/rails/social_cards"
    assert_response :success

    # Bad preview should not appear in list
    assert_select "a", text: "bad", count: 0
  ensure
    FileUtils.rm_rf(preview_dir)
  end

  test("handles Active Storage attachment errors gracefully") do
    # Create a card that uses image_to_data_url
    image_card_class = Class.new(SocialConstruct::BaseCard) do
      attr_accessor(:image)

      def initialize(image)
        @image = image
        super()
      end

      def template_name
        "image_card"
      end

      def template_assigns
        super.merge(image_url: image_to_data_url(@image))
      end
    end

    # Create template
    template_dir = Rails.root.join("app/views/social_cards")
    FileUtils.mkdir_p(template_dir)
    File.write(
      template_dir.join("image_card.html.erb"),
      <<~ERB
        <div style="width: 1200px; height: 630px;">
          <% if @image_url %>
            <img src="<%= @image_url %>" style="max-width: 100%;">
          <% else %>
            <p>No image available</p>
          <% end %>
        </div>
      ERB
    )

    controller = Class.new(ActionController::Base) do
      include(SocialConstruct::Controller)

      def show
        # Pass a non-image object
        card = image_card_class.new("not an image")
        send_social_card(card)
      end
    end

    Rails.application.routes.draw do
      get "/image_card", to: controller.action(:show)
      mount SocialConstruct::Engine => "/rails"
    end

    get "/image_card"

    assert_response :success
    assert_equal "image/png", response.content_type
    # Should still generate a PNG, just without the image
  ensure
    FileUtils.rm_rf(template_dir)
  end

  test("caching works even with errors") do
    Rails.cache.clear

    # Use a class variable to track render count
    CountingCard = Class.new(SocialConstruct::BaseCard) do
      @@render_count = 0

      def self.render_count
        @@render_count
      end

      def self.reset_count
        @@render_count = 0
      end

      def to_png
        @@render_count += 1
        raise "First attempt fails" if @@render_count == 1
        "success png data"
      end
    end

    CountingCard.reset_count

    counting_controller = Class.new(ActionController::Base) do
      include(SocialConstruct::Controller)

      def counted
        card = CountingCard.new
        send_social_card(card, cache_key: "counted_card")
      end
    end

    Rails.application.routes.draw do
      get "/counted", to: counting_controller.action(:counted)
      mount SocialConstruct::Engine => "/rails"
    end

    # First request fails but returns fallback
    get "/counted"
    assert_response :success
    assert_equal 1, CountingCard.render_count

    # Second request should try again (not cached due to error)
    get "/counted"
    assert_response :success
    assert_equal 2, CountingCard.render_count

    # Third request should use cache
    get "/counted"
    assert_response :success
    # No additional render
    assert_equal 2, CountingCard.render_count
  ensure
    Object.send(:remove_const, :CountingCard) if defined?(CountingCard)
  end
end

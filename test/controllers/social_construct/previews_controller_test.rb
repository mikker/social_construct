require "test_helper"

module SocialConstruct
  class PreviewsControllerTest < ActionDispatch::IntegrationTest
    setup do
      Rails.application.config.social_construct.show_previews = true
      # Ensure preview classes are loaded
      require Rails.root.join("test/social_cards/previews/dummy_card_preview.rb")
    end

    test "index lists all preview classes" do
      get "/rails/social_cards/previews"

      assert_response :success
      assert_select "h1", "Social Card Previews"
      assert_select "p.text-lg", text: "Dummy card"
      assert_select "p.text-sm", text: "DummyCardPreview"
    end

    test "show displays examples for a preview class" do
      get "/rails/social_cards/previews/dummy_card"

      assert_response :success
      assert_select "h1", "Dummy card"
      assert_select "a", text: "Basic example"
      assert_select "a", text: "Everything example"
      assert_select "a", text: "Image example"
      assert_select "a", text: "Local fonts examle"
      assert_select "a", text: "Remote fonts example"
    end

    test "show redirects when preview class not found" do
      get "/rails/social_cards/previews/nonexistent"

      assert_redirected_to "/rails/social_cards/previews"
      assert_equal "Preview not found", flash[:alert]
    end

    test "preview renders card as PNG" do
      get "/rails/social_cards/previews/dummy_card/basic_example.png"

      assert_response :success
      assert_equal "image/png", response.content_type
      refute_empty response.body
    end

    test "preview renders card as HTML" do
      get "/rails/social_cards/previews/dummy_card/basic_example.html"

      assert_response :success
      assert_equal "text/html; charset=utf-8", response.content_type
    end

    test "preview raises NoMethodError for invalid example name" do
      assert_raises(NoMethodError) do
        get "/rails/social_cards/previews/dummy_card/nonexistent_method.png"
      end
    end

    test "preview redirects when preview class not found" do
      get "/rails/social_cards/previews/nonexistent/example.png"

      assert_redirected_to "/rails/social_cards/previews"
      assert_equal "Preview not found", flash[:alert]
    end

    test "preview raises NoMethodError when example method not found" do
      assert_raises(NoMethodError) do
        get "/rails/social_cards/previews/dummy_card/nonexistent.png"
      end
    end
  end
end

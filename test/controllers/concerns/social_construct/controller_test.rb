require "test_helper"

module SocialConstruct
  class ControllerTest < ActionController::TestCase
    class TestController < ActionController::Base
      include SocialConstruct::Controller

      def show
        @card = BasicExampleCard.new
        render(@card)
      end

      def show_with_cache
        @card = BasicExampleCard.new
        send_social_card(@card, cache_key: "test-card-123", expires_in: 1.hour)
      end

      def show_dev_cache
        card = BasicExampleCard.new
        send_social_card(card, cache_key: "dev-cache-test", cache_in_development: true)
      end

      def show_with_error
        @card = BasicExampleCard.new
        @card.stub(:to_png) { raise "Test error" }
        send_social_card(@card)
      end
    end

    setup do
      @controller = TestController.new
      @routes = ActionDispatch::Routing::RouteSet.new.tap do |r|
        r.draw do
          get("show", to: "social_construct/controller_test/test#show")
          get("show_with_cache", to: "social_construct/controller_test/test#show_with_cache")
          get("show_with_error", to: "social_construct/controller_test/test#show_with_error")
          get("show_dev_cache", to: "social_construct/controller_test/test#show_dev_cache")
        end
      end
    end

    test("registers PNG mime type") do
      assert Mime::Type.lookup("image/png")
      assert_equal :png, Mime::Type.lookup("image/png").symbol
    end

    test("send_social_card sends PNG data") do
      get :show_with_cache

      assert_response :success
      assert_equal "image/png", response.content_type
      assert response.body.start_with?("\x89PNG".b)
      assert_match /inline; filename="test-social-card.png"/, response.headers["Content-Disposition"]
    end

    test("send_social_card with caching uses cache") do
      # Setup memory cache for this test
      original_cache = Rails.cache
      Rails.cache = ActiveSupport::Cache::MemoryStore.new
      original_env = Rails.env
      Rails.env = ActiveSupport::StringInquirer.new("production")
      cache_key = "test-card-123"

      # First call should cache
      get :show_with_cache
      assert_response :success
      cached_value = Rails.cache.read(cache_key)
      assert_not_nil cached_value
      assert response.body.start_with?("\x89PNG".b)

      # Second call should use cache by verifying same content
      first_response = response.body
      get :show_with_cache
      assert_equal first_response, response.body
    ensure
      Rails.env = original_env
      Rails.cache = original_cache
    end

    test("send_social_card without cache key generates fresh PNG") do
      @controller.define_singleton_method(:show_with_cache) do
        card = BasicExampleCard.new
        send_social_card(card)
      end

      get :show_with_cache
      assert_response :success
      assert response.body.start_with?("\x89PNG".b)
    end

    test("send_social_card handles errors with fallback PNG") do
      @controller.define_singleton_method(:show_with_error) do
        card = BasicExampleCard.new
        card.define_singleton_method(:to_png) { raise "Test error" }
        send_social_card(card)
      end

      get :show_with_error
      assert_response :success
      assert_equal "image/png", response.content_type
      # Check for 1x1 transparent PNG
      assert response.body.bytesize > 0
    end

    test("render method handles social card with PNG format") do
      get :show, params: {}, format: :png

      assert_response :success
      assert_equal "image/png", response.content_type
    end

    test("render method handles social card with HTML format") do
      get :show, params: {}, format: :html

      assert_response :success
      assert_equal "text/html; charset=utf-8", response.content_type
      assert_match /<html/, response.body
    end

    test("render method falls back to super for non-social cards") do
      @controller.define_singleton_method(:show) do
        render plain: "Regular render"
      end

      get :show
      assert_response :success
      assert_equal "Regular render", response.body
    end

    test("caching headers are set in production") do
      original_env = Rails.env
      Rails.env = ActiveSupport::StringInquirer.new("production")

      get :show_with_cache
      assert response.headers["Cache-Control"]&.include?("public")
    ensure
      Rails.env = original_env
    end

    test("caching headers are not set in development") do
      original_env = Rails.env
      Rails.env = ActiveSupport::StringInquirer.new("development")

      get :show_with_cache
      refute response.headers["Cache-Control"]&.include?("public")
    ensure
      Rails.env = original_env
    end

    test("cache_in_development option allows caching in dev") do
      original_cache = Rails.cache
      Rails.cache = ActiveSupport::Cache::MemoryStore.new
      original_env = Rails.env
      Rails.env = ActiveSupport::StringInquirer.new("development")

      get :show_dev_cache
      assert_response :success
      assert Rails.cache.exist?("dev-cache-test")
    ensure
      Rails.env = original_env
      Rails.cache = original_cache
    end
  end
end

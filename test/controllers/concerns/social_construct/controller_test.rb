require "test_helper"
require "minitest/mock"

module SocialConstruct
  class ControllerTest < ActionController::TestCase
    class TestCard < BaseCard
      attr_accessor :title
      
      def initialize(title = "Test")
        super()
        @title = title
      end
      
      def template_name
        "test_card"
      end
    end
    
    class TestController < ActionController::Base
      include SocialConstruct::Controller
      
      def show
        @card = TestCard.new(params[:title] || "Default Title")
        send_social_card(@card)
      end
      
      def show_with_cache
        @card = TestCard.new(params[:title] || "Cached Title")
        send_social_card(@card, cache_key: "test_cache_key", cache_ttl: 1.hour)
      end
      
      def show_with_array_cache
        @card = TestCard.new(params[:title] || "Array Cache")
        send_social_card(@card, cache_key: ["test", "array", "key"])
      end
      
      def show_html
        @card = TestCard.new("HTML Test")
        send_social_card(@card, format: :html)
      end
      
      def error_card
        # Force an error by passing nil
        send_social_card(nil)
      end
    end
    
    setup do
      @controller = TestController.new
      @routes = ActionDispatch::Routing::RouteSet.new
      @routes.draw do
        get "show" => "social_construct/controller_test/test#show"
        get "show_with_cache" => "social_construct/controller_test/test#show_with_cache"
        get "show_with_array_cache" => "social_construct/controller_test/test#show_with_array_cache"
        get "show_html" => "social_construct/controller_test/test#show_html"
        get "error_card" => "social_construct/controller_test/test#error_card"
      end
      
      # Create test template
      @template_dir = Rails.root.join("app/views/social_cards")
      FileUtils.mkdir_p(@template_dir)
      File.write(@template_dir.join("test_card.html.erb"), "<h1><%= @title %></h1>")
      
      # Clear cache before each test
      Rails.cache.clear
    end
    
    teardown do
      FileUtils.rm_rf(@template_dir)
      Rails.cache.clear
    end
    
    test "registers png mime type" do
      assert Mime::Type.lookup("image/png")
      assert_equal :png, Mime::Type.lookup("image/png").symbol
    end
    
    test "send_social_card renders PNG by default" do
      # Mock the card's to_png method
      mock_card = Minitest::Mock.new
      mock_card.expect :to_png, "fake png data"
      
      @controller.stub :render, nil do
        @controller.stub :send_data, ->(data, options) {
          assert_equal "fake png data", data
          assert_equal "image/png", options[:type]
          assert_equal :inline, options[:disposition]
        } do
          @controller.instance_variable_set(:@card, mock_card)
          @controller.show
        end
      end
      
      mock_card.verify
    end
    
    test "send_social_card renders HTML when format is html" do
      rendered_html = false
      
      @controller.stub :render, ->(options) {
        if options[:html]
          rendered_html = true
          assert_equal "<h1>HTML Test</h1>", options[:html]
          assert_equal "social_cards", options[:layout]
        end
      } do
        @controller.show_html
      end
      
      assert rendered_html
    end
    
    test "send_social_card uses cache when cache_key provided" do
      # First request - cache miss
      cache_miss = true
      mock_card = TestCard.new("Cached")
      
      @controller.stub :send_data, ->(data, options) {
        if cache_miss
          Rails.cache.write("social_cards/test_cache_key", data, expires_in: 1.hour)
        end
      } do
        @controller.instance_variable_set(:@card, mock_card)
        @controller.show_with_cache
      end
      
      # Verify cache was written
      assert Rails.cache.exist?("social_cards/test_cache_key")
      
      # Second request - cache hit (no PNG generation)
      cache_miss = false
      render_called = false
      
      mock_card.stub :to_png, -> { render_called = true; "new png data" } do
        @controller.stub :send_data, ->(data, options) {
          # Should get cached data, not new data
          refute_equal "new png data", data
        } do
          @controller.instance_variable_set(:@card, mock_card)
          @controller.show_with_cache
        end
      end
      
      refute render_called
    end
    
    test "send_social_card handles array cache keys" do
      @controller.stub :send_data, ->(data, options) {
        # Just verify it doesn't error
      } do
        @controller.show_with_array_cache
      end
      
      # Check that array key was properly converted
      assert Rails.cache.exist?("social_cards/test/array/key")
    end
    
    test "send_social_card handles errors with transparent PNG fallback" do
      error_handled = false
      
      @controller.stub :send_data, ->(data, options) {
        error_handled = true
        # Verify it's a valid PNG header
        assert data.start_with?("\x89PNG")
        assert_equal "image/png", options[:type]
      } do
        @controller.error_card
      end
      
      assert error_handled
    end
    
    test "send_social_card renders HTML format when requested" do
      mock_card = Minitest::Mock.new
      mock_card.expect :render, "<h1>HTML</h1>"
      
      html_rendered = false
      @controller.stub :render, ->(options) {
        if options[:html]
          html_rendered = true
          assert_equal "<h1>HTML</h1>", options[:html]
        end
      } do
        @controller.instance_variable_set(:@card, mock_card)
        @controller.show_html
      end
      
      assert html_rendered
      mock_card.verify
    end
    
    test "send_social_card respects cache TTL" do
      # Test with custom TTL
      mock_card = TestCard.new("TTL Test")
      
      write_options = nil
      Rails.cache.stub :fetch, ->(key, options, &block) {
        write_options = options
        block.call
      } do
        @controller.stub :send_data, nil do
          @controller.instance_variable_set(:@card, mock_card)
          @controller.show_with_cache
        end
      end
      
      assert_equal 1.hour, write_options[:expires_in]
    end
    
    test "send_social_card uses default TTL when not specified" do
      mock_card = TestCard.new("Default TTL")
      
      write_options = nil
      Rails.cache.stub :fetch, ->(key, options, &block) {
        write_options = options
        block.call
      } do
        @controller.stub :send_data, nil do
          @controller.instance_variable_set(:@card, mock_card)
          @controller.send(:send_social_card, mock_card, cache_key: "default_ttl")
        end
      end
      
      assert_equal 6.hours, write_options[:expires_in]
    end
  end
end
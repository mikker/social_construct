require "test_helper"
require "minitest/mock"
require "ferrum"

module SocialConstruct
  class BaseCardTest < ActiveSupport::TestCase
    class TestCard < BaseCard
      attr_accessor :title, :description

      def initialize
        @title = "Test Title"
        @description = "Test Description"
      end

      private

      def template_assigns
        {title: @title, description: @description, card: self}
      end
    end

    class CustomTemplateCard < BaseCard
      def template_name
        "custom_card"
      end
    end

    setup do
      @card = TestCard.new
      Rails.application.config.social_construct.template_path = "social_cards"
    end

    test("initializes with default width and height") do
      assert_equal 1200, @card.width
      assert_equal 630, @card.height
    end

    test("initializes with debug mode off by default") do
      refute BaseCard.debug
    end

    test("can enable debug mode") do
      original_debug = BaseCard.debug
      BaseCard.debug = true
      assert BaseCard.debug
    ensure
      BaseCard.debug = original_debug
    end

    test("generates correct template name from class name") do
      assert_equal "social_cards/test_card", @card.send(:template_name)
    end

    test("allows custom template name") do
      card = CustomTemplateCard.new
      # CustomTemplateCard overrides template_name to return just "custom_card"
      assert_equal "custom_card", card.send(:template_name)
    end

    test("provides template assigns with instance variables") do
      assigns = @card.send(:template_assigns)
      assert_equal "Test Title", assigns[:title]
      assert_equal "Test Description", assigns[:description]
      assert_equal @card, assigns[:card]
    end

    test("uses configured template path") do
      assert_equal "social_cards", @card.send(:template_path)
    end

    test("can override template path configuration") do
      Rails.application.config.social_construct.template_path = "custom_path"
      assert_equal "custom_path", @card.send(:template_path)
    end

    test("render returns HTML string") do
      # Create a test template
      template_dir = Rails.root.join("app/views/social_cards")
      FileUtils.rm_rf(template_dir) # Clean up first
      FileUtils.mkdir_p(template_dir)
      template_path = template_dir.join("test_card.html.erb")

      template_content = "<h1><%= title %></h1><p><%= description %></p>"
      File.write(template_path, template_content)
      
      # Clear the view cache to ensure fresh template load
      ApplicationController.view_paths.each do |resolver|
        resolver.clear_cache if resolver.respond_to?(:clear_cache)
      end

      html = @card.render
      assert html.include?("Test Title"), "HTML should include title: #{html}"
      assert html.include?("Test Description"), "HTML should include description: #{html}"
    ensure
      FileUtils.rm_rf(template_dir)
    end

    test("render with layout when available") do
      template_dir = Rails.root.join("app/views/social_cards")
      layout_dir = Rails.root.join("app/views/layouts")
      
      # Clean up first
      FileUtils.rm_rf(template_dir)
      FileUtils.rm_rf(layout_dir)
      
      FileUtils.mkdir_p(template_dir)
      FileUtils.mkdir_p(layout_dir)

      template_path = template_dir.join("test_card.html.erb")
      layout_path = layout_dir.join("social_cards.html.erb")

      File.write(template_path, "<h1><%= title %></h1>")
      File.write(layout_path, "<html><body><%= yield %></body></html>")

      # Clear the view cache to ensure fresh template load
      ApplicationController.view_paths.each do |resolver|
        resolver.clear_cache if resolver.respond_to?(:clear_cache)
      end

      html = @card.render
      assert_includes html, "<html>"
      assert_includes html, "<body>"
      assert_includes html, "<h1>Test Title</h1>"
    ensure
      FileUtils.rm_rf(template_dir)
      FileUtils.rm_rf(layout_dir)
    end

    test("image_to_data_url converts image to base64 data URL") do
      # The actual image_to_data_url expects an ActiveStorage attachment with variant support
      # For this test, we'll use a mock that behaves like an attachment
      processed_blob = Minitest::Mock.new
      processed_blob.expect :content_type, "image/png"
      processed_blob.expect :download, "fake image data"

      variant = Minitest::Mock.new
      variant.expect :processed, processed_blob

      image = Minitest::Mock.new
      image.expect :attached?, true
      image.expect :variant, variant, [{saver: {quality: 90, strip: true}}]

      data_url = @card.send(:image_to_data_url, image)

      expected_base64 = Base64.strict_encode64("fake image data")
      assert_equal "data:image/png;base64,#{expected_base64}", data_url

      image.verify
      variant.verify
      processed_blob.verify
    end

    test("image_to_data_url returns nil for non-attached objects") do
      # For non-ActiveStorage objects, the method should return nil
      non_image = Object.new
      def non_image.attached?
        false
      end

      assert_nil @card.send(:image_to_data_url, non_image)
    end

    test("image_to_data_url handles errors gracefully") do
      image = Minitest::Mock.new
      image.expect :attached?, true
      image.expect(:variant, nil) do |options|
        raise StandardError, "Download failed"
      end

      assert_nil @card.send(:image_to_data_url, image)
      image.verify
    end

    test("log_debug logs messages in debug mode") do
      original_debug = BaseCard.debug
      BaseCard.debug = true
      card = TestCard.new

      # Capture logs
      logged = false
      Rails.logger.stub(:info, -> (msg) { logged = true if msg.include?("[SocialCard]") }) do
        card.send(:log_debug, "Test message")
      end

      assert logged
    ensure
      BaseCard.debug = original_debug
    end

    test("log_debug does not log when debug mode is off") do
      logged = false
      Rails.logger.stub(:info, -> (msg) { logged = true }) do
        @card.send(:log_debug, "Test message")
      end

      refute logged
    end

    test("log_debug supports different log levels") do
      original_debug = BaseCard.debug
      BaseCard.debug = true
      card = TestCard.new

      error_logged = false
      Rails.logger.stub(:error, -> (msg) { error_logged = true if msg.include?("[SocialCard]") }) do
        card.send(:log_debug, "Error message", :error)
      end

      assert error_logged
    ensure
      BaseCard.debug = original_debug
    end

    test("browser options includes default flags") do
      # Since browser_options is a private method of to_png, we test its effects
      # by mocking the browser initialization
      skip "browser_options is internal to to_png method"
    end

    test("to_png requires ferrum browser") do
      # Skip this test if we can't create a simple template
      template_dir = Rails.root.join("app/views/social_cards")
      FileUtils.mkdir_p(template_dir)
      File.write(template_dir.join("test_card.html.erb"), "<h1>Test</h1>")

      # We can't actually test PNG generation without a real browser
      # but we can test that the method exists and handles errors
      assert_respond_to @card, :to_png

      # Mock Ferrum to avoid needing a real browser
      mock_browser = Minitest::Mock.new
      mock_network = Minitest::Mock.new
      
      # The actual implementation uses data:text/html;charset=utf-8 with URL encoding
      mock_browser.expect :goto, nil, [String]
      mock_browser.expect :set_viewport, nil, [], width: 1200, height: 630
      mock_browser.expect :network, mock_network
      mock_network.expect :wait_for_idle, nil
      mock_browser.expect :execute, nil, [String] # For JS image/font loading
      mock_browser.expect :execute, nil, [String] # For content paint check
      mock_browser.expect :screenshot, "fake png data", [], encoding: :binary, quality: 100, full: false
      mock_browser.expect :quit, nil

      Ferrum::Browser.stub(:new, mock_browser) do
        png_data = @card.to_png
        assert_equal "fake png data", png_data
      end

      mock_browser.verify
      mock_network.verify
    ensure
      FileUtils.rm_rf(template_dir)
    end

    test("font_to_data_url converts font file to base64 data URL") do
      # Create a temporary font file
      font_dir = Rails.root.join("app/assets/fonts")
      FileUtils.mkdir_p(font_dir)
      font_path = font_dir.join("test-font.woff2")
      File.write(font_path, "fake font data")

      data_url = @card.send(:font_to_data_url, "test-font.woff2")
      expected_base64 = Base64.strict_encode64("fake font data")
      assert_equal "data:font/woff2;base64,#{expected_base64}", data_url
    ensure
      FileUtils.rm_rf(font_dir)
    end

    test("font_to_data_url returns nil for non-existent fonts") do
      assert_nil @card.send(:font_to_data_url, "non-existent.woff2")
    end

    test("font_to_data_url returns nil for fonts exceeding 2MB") do
      font_dir = Rails.root.join("app/assets/fonts")
      FileUtils.mkdir_p(font_dir)
      font_path = font_dir.join("huge-font.woff2")
      # Create a 2.1MB file
      File.write(font_path, "x" * 2_100_000)

      assert_nil @card.send(:font_to_data_url, "huge-font.woff2")
    ensure
      FileUtils.rm_rf(font_dir)
    end

    test("image_data_url converts image file to base64 data URL") do
      # Create a temporary image file
      image_dir = Rails.root.join("app/assets/images")
      FileUtils.mkdir_p(image_dir)
      image_path = image_dir.join("test-image.png")
      File.write(image_path, "fake image data")

      data_url = @card.send(:image_data_url, "test-image.png")
      expected_base64 = Base64.strict_encode64("fake image data")
      assert_equal "data:image/png;base64,#{expected_base64}", data_url
    ensure
      FileUtils.rm_rf(image_dir)
    end

    test("image_data_url returns nil for non-existent images") do
      assert_nil @card.send(:image_data_url, "non-existent.png")
    end

    test("image_data_url returns nil for images exceeding 2MB") do
      image_dir = Rails.root.join("app/assets/images")
      FileUtils.mkdir_p(image_dir)
      image_path = image_dir.join("huge-image.png")
      # Create a 2.1MB file
      File.write(image_path, "x" * 2_100_000)

      assert_nil @card.send(:image_data_url, "huge-image.png")
    ensure
      FileUtils.rm_rf(image_dir)
    end

    test("generate_font_face creates CSS with data URL") do
      font_dir = Rails.root.join("app/assets/fonts")
      FileUtils.mkdir_p(font_dir)
      font_path = font_dir.join("test-font.woff2")
      File.write(font_path, "fake font data")

      css = @card.send(:generate_font_face, "TestFont", "test-font.woff2", weight: "400", style: "italic")
      
      assert_includes css, "@font-face"
      assert_includes css, "font-family: 'TestFont'"
      assert_includes css, "font-weight: 400"
      assert_includes css, "font-style: italic"
      assert_includes css, "font-display: swap"
      assert_includes css, "src: url('data:font/woff2;base64,"
    ensure
      FileUtils.rm_rf(font_dir)
    end

    test("generate_font_face returns empty string for non-existent fonts") do
      css = @card.send(:generate_font_face, "TestFont", "non-existent.woff2")
      assert_equal "", css
    end

    test("to_png uses tempfile for large HTML content") do
      # Create a new card class for this test to avoid template conflicts
      large_card_class = Class.new(BaseCard) do
        def template_name
          "social_cards/large_test_card"
        end
      end
      
      large_card = large_card_class.new
      
      template_dir = Rails.root.join("app/views/social_cards")
      FileUtils.mkdir_p(template_dir)
      File.write(template_dir.join("large_test_card.html.erb"), "<div style='white-space: pre-wrap;'>#{'x' * 1_000_000}</div>")

      # Mock the browser and tempfile
      mock_browser = Minitest::Mock.new
      mock_network = Minitest::Mock.new
      
      # Expect file:// URL instead of data URL for large content
      mock_browser.expect :goto, nil, [/^file:\/\//]
      mock_browser.expect :set_viewport, nil, [], width: 1200, height: 630
      mock_browser.expect :network, mock_network
      mock_network.expect :wait_for_idle, nil
      mock_browser.expect :execute, nil, [String] # For JS image/font loading
      mock_browser.expect :execute, nil, [String] # For content paint check
      mock_browser.expect :screenshot, "fake png data", [], encoding: :binary, quality: 100, full: false
      mock_browser.expect :quit, nil

      Ferrum::Browser.stub(:new, mock_browser) do
        png_data = large_card.to_png
        assert_equal "fake png data", png_data
      end

      mock_browser.verify
      mock_network.verify
    ensure
      FileUtils.rm_rf(template_dir)
    end
  end
end

require "test_helper"

module SocialConstruct
  class BaseCardTest < ActiveSupport::TestCase
    class TestCard < BaseCard
      attr_accessor :custom_width, :custom_height

      def width
        @custom_width || super
      end

      def height
        @custom_height || super
      end

      def template_assigns
        {title: "Test Card"}
      end
    end

    setup do
      @card = TestCard.new
      BaseCard.debug = false
    end

    teardown do
      BaseCard.debug = false
    end

    test("default dimensions are 1200x630") do
      assert_equal 1200, @card.width
      assert_equal 630, @card.height
    end

    test("custom dimensions can be set") do
      @card.custom_width = 800
      @card.custom_height = 400
      assert_equal 800, @card.width
      assert_equal 400, @card.height
    end

    test("template_name uses underscored class name") do
      template_path = Rails.application.config.social_construct.template_path
      expected = "#{template_path}/test_card"
      assert_equal expected, @card.send(:template_name)
    end

    test("template_name works with BasicExampleCard") do
      card = BasicExampleCard.new
      template_path = Rails.application.config.social_construct.template_path
      expected = "#{template_path}/basic_example_card"
      assert_equal expected, card.send(:template_name)
    end

    test("layout_name returns layout path when it exists") do
      # The dummy app has a social_cards layout
      layout_path = "layouts/#{Rails.application.config.social_construct.template_path}"
      assert_equal layout_path, @card.send(:layout_name)
    end

    test("layout_name returns path when layout exists") do
      # Mock template_exists? to return true
      @card.stub(:template_exists?, true) do
        layout_path = "layouts/#{Rails.application.config.social_construct.template_path}"
        assert_equal layout_path, @card.send(:layout_name)
      end
    end

    test("render method calls ApplicationController.render with correct params") do
      result = nil
      expected_params = {
        template: @card.send(:template_name),
        layout: @card.send(:layout_name),
        locals: {
          title: "Test Card",
          default_url_options: Rails.application.config.action_controller.default_url_options
        }
      }

      ApplicationController.stub(
        :render,
        lambda { |params|
          assert_equal expected_params, params
          "<html>Test</html>"
        }
      ) do
        result = @card.render
      end

      assert_equal "<html>Test</html>", result
    end

    test("image_data_url converts image file to data URL") do
      # Use an actual image from the dummy app
      data_url = @card.send(:image_data_url, "wavy_circles.png")

      assert_not_nil data_url
      assert data_url.start_with?("data:image/png;base64,")
      assert data_url.length > 100
    end

    test("image_data_url returns nil for non-existent file") do
      data_url = @card.send(:image_data_url, "non_existent.png")
      assert_nil data_url
    end

    test("image_data_url handles absolute paths") do
      path = Rails.root.join("app", "assets", "images", "wavy_circles.png")
      data_url = @card.send(:image_data_url, path.to_s)

      assert_not_nil data_url
      assert data_url.start_with?("data:image/png;base64,")
    end

    test("image_content_type returns correct MIME types") do
      assert_equal "image/png", @card.send(:image_content_type, "test.png")
      assert_equal "image/jpeg", @card.send(:image_content_type, "test.jpg")
      assert_equal "image/jpeg", @card.send(:image_content_type, "test.jpeg")
      assert_equal "image/gif", @card.send(:image_content_type, "test.gif")
      assert_equal "image/svg+xml", @card.send(:image_content_type, "test.svg")
      assert_equal "image/webp", @card.send(:image_content_type, "test.webp")
      assert_equal "image/png", @card.send(:image_content_type, "test.unknown")
    end

    test("font_to_data_url converts font file to data URL") do
      # Use actual font from dummy app
      data_url = @card.send(:font_to_data_url, "Recursive_VF_1.085--subset-GF_latin_basic.woff2")

      assert_not_nil data_url
      assert data_url.start_with?("data:font/woff2;base64,")
      assert data_url.length > 100
    end

    test("font_to_data_url returns nil for non-existent file") do
      data_url = @card.send(:font_to_data_url, "non_existent.woff2")
      assert_nil data_url
    end

    test("font_content_type returns correct MIME types") do
      assert_equal "font/woff2", @card.send(:font_content_type, "test.woff2")
      assert_equal "font/woff", @card.send(:font_content_type, "test.woff")
      assert_equal "font/truetype", @card.send(:font_content_type, "test.ttf")
      assert_equal "font/opentype", @card.send(:font_content_type, "test.otf")
      assert_equal "application/vnd.ms-fontobject", @card.send(:font_content_type, "test.eot")
      assert_equal "font/truetype", @card.send(:font_content_type, "test.unknown")
    end

    test("generate_font_face creates valid CSS") do
      @card.stub(:font_to_data_url, "data:font/woff2;base64,ABC123") do
        css = @card.send(:generate_font_face, "MyFont", "font.woff2", weight: "bold", style: "italic")

        assert_includes css, "@font-face"
        assert_includes css, "font-family: 'MyFont'"
        assert_includes css, "src: url('data:font/woff2;base64,ABC123')"
        assert_includes css, "font-weight: bold"
        assert_includes css, "font-style: italic"
        assert_includes css, "font-display: swap"
      end
    end

    test("generate_font_face returns empty string when font not found") do
      css = @card.send(:generate_font_face, "MyFont", "non_existent.woff2")
      assert_equal "", css
    end

    test("debug mode logs messages") do
      BaseCard.debug = true

      # Capture log output
      logger_mock = Minitest::Mock.new
      logger_mock.expect(:info, nil, ["[SocialCard] Test message"])

      Rails.stub(:logger, logger_mock) do
        @card.send(:log_debug, "Test message")
      end

      assert_mock logger_mock
    end

    test("debug mode respects log level") do
      BaseCard.debug = true

      logger_mock = Minitest::Mock.new
      logger_mock.expect(:error, nil, ["[SocialCard] Error message"])

      Rails.stub(:logger, logger_mock) do
        @card.send(:log_debug, "Error message", :error)
      end

      assert_mock logger_mock
    end

    test("debug mode does not log when disabled") do
      BaseCard.debug = false

      called = false
      logger_stub = Object.new
      logger_stub.define_singleton_method(:info) { |_| called = true }

      Rails.stub(:logger, logger_stub) do
        @card.send(:log_debug, "Test message")
      end

      refute called, "Logger should not be called when debug is disabled"
    end

    test("to_png generates PNG data") do
      skip "Requires Chrome/Chromium to be installed" unless chrome_available?

      # Use a real card from the dummy app
      card = BasicExampleCard.new
      png_data = card.to_png

      assert_not_nil png_data
      assert png_data.start_with?("\x89PNG".b)
      assert png_data.bytesize > 1000
    end

    test("to_png handles large HTML content with temp file") do
      skip "Requires Chrome/Chromium to be installed" unless chrome_available?

      # Create a card that renders large HTML
      card = BasicExampleCard.new
      large_html = "<html><body>" + ("X" * 1_100_000) + "</body></html>"

      card.stub(:render, large_html) do
        png_data = card.to_png
        assert_not_nil png_data
        assert png_data.start_with?("\x89PNG".b)
      end
    end

    test("to_png uses Docker options in production") do
      skip "Requires Chrome/Chromium to be installed" unless chrome_available?

      original_env = Rails.env
      Rails.env = ActiveSupport::StringInquirer.new("production")

      # We can't easily test the actual browser options, but we can ensure it doesn't crash
      card = BasicExampleCard.new
      png_data = card.to_png

      assert_not_nil png_data
      assert png_data.start_with?("\x89PNG".b)
    ensure
      Rails.env = original_env
    end

    test("to_png handles errors gracefully") do
      skip "Requires Chrome/Chromium to be installed" unless chrome_available?

      card = BasicExampleCard.new
      card.stub(:render, proc { raise "Render error" }) do
        assert_raises(RuntimeError) { card.to_png }
      end
    end

    test("attachment_data_url handles Active Storage attachments") do
      # This would require setting up Active Storage in tests
      # For now, we'll skip this test
      skip "Active Storage not configured for tests"
    end

    test("template_path returns configured path") do
      assert_equal Rails.application.config.social_construct.template_path, @card.send(:template_path)
    end

    private

    def chrome_available?
      # Check if Chrome/Chromium is available for Ferrum
      begin
        browser = Ferrum::Browser.new(headless: true, timeout: 5)
        browser.quit
        true
      rescue => e
        false
      end
    end
  end
end

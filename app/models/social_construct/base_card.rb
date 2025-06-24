require "base64"
require "tempfile"

module SocialConstruct
  class BaseCard
    include ActionView::Helpers
    include Rails.application.routes.url_helpers

    cattr_accessor :debug, default: false

    def width
      @width || 1200
    end

    def height
      @height || 630
    end

    def render
      ApplicationController.render(
        template: template_name,
        layout: layout_name,
        locals: template_assigns.merge(
          default_url_options: Rails.application.config.action_controller.default_url_options
        )
      )
    end

    def to_png
      log_debug("Starting PNG generation for #{self.class.name}")

      # Use 1x resolution for better performance and reliability
      browser_options = {
        headless: true,
        timeout: 30,
        window_size: [width, height]
      }

      # Add Docker-specific options in production
      if Rails.env.production? || ENV["DOCKER_CONTAINER"].present?
        browser_options[:browser_options] = {
          :"no-sandbox" => nil,
          :"disable-dev-shm-usage" => nil,
          :"disable-gpu" => nil,
          :"disable-software-rasterizer" => nil,
          :"disable-web-security" => nil,
          :"force-color-profile" => "srgb"
        }
        log_debug("Using production browser options")
      end

      browser = Ferrum::Browser.new(browser_options)

      html_content = render
      log_debug("HTML content length: #{html_content.length} bytes")
      log_debug("HTML encoding: #{html_content.encoding}")

      # For large HTML content (with embedded images), use a temp file instead of data URL
      # 1MB threshold
      if html_content.length > 1_000_000
        log_debug("HTML too large for data URL, using temp file")

        require "tempfile"

        temp_file = Tempfile.new(["social_card", ".html"])
        temp_file.write(html_content)
        temp_file.rewind
        temp_file.close

        begin
          browser.goto("file://#{temp_file.path}")
        ensure
          # Will be deleted after browser loads it
          temp_file.unlink
        end
      else
        # Ensure UTF-8 encoding
        html_content = html_content.force_encoding("UTF-8")
        encoded_html = ERB::Util.url_encode(html_content)

        browser.goto("data:text/html;charset=utf-8,#{encoded_html}")
      end

      browser.set_viewport(width: width, height: height)

      # Wait for the page to fully load
      browser.network.wait_for_idle

      # Wait for all images and fonts to load
      browser.execute(
        <<~JS
          return new Promise((resolve) => {
            // Check if all images are loaded
            const images = Array.from(document.querySelectorAll('img'));
            const imagePromises = images.map(img => {
              if (img.complete) return Promise.resolve();
              return new Promise(res => {
                img.addEventListener('load', res);
                img.addEventListener('error', res);
              });
            });

            // Check document fonts
            const fontPromise = document.fonts?.ready || Promise.resolve();

            // Wait for everything
            Promise.all([...imagePromises, fontPromise]).then(() => {
              // Small delay to ensure rendering is complete
              requestAnimationFrame(() => {
                setTimeout(resolve, 50);
              });
            });
          });
        JS
      )

      # Log page readiness
      if debug
        page_ready = browser.evaluate("document.readyState")
        log_debug("Page ready state: #{page_ready}")

        # Log computed styles to check if CSS is applied
        body_bg = browser.evaluate("window.getComputedStyle(document.body).backgroundColor")
        log_debug("Body background color: #{body_bg}")

        # Check if content is visible
        has_title = browser.evaluate("!!document.querySelector('.title')")
        title_text = browser.evaluate("document.querySelector('.title')?.textContent") if has_title
        log_debug("Has title element: #{has_title}, Title text: #{title_text}")

        # Check HTML body content
        body_html_length = browser.evaluate("document.body.innerHTML.length")
        log_debug("Body HTML length: #{body_html_length}")
      end

      # Ensure content is painted before screenshot
      browser.execute(
        <<~JS
          // Force layout and paint
          document.body.offsetHeight;
          // Check if we have visible content
          const hasContent = document.body.textContent.trim().length > 0 ||
                            document.querySelectorAll('img').length > 0;
          if (!hasContent) {
            console.warn('Page appears to have no visible content');
          }
          return hasContent;
        JS
      )

      screenshot = browser.screenshot(
        encoding: :binary,
        quality: 100,
        full: false
      )

      log_debug("Screenshot generated, size: #{screenshot.bytesize} bytes")

      screenshot
    rescue => e
      log_debug("Ferrum screenshot failed: #{e.message}", :error)
      log_debug("Backtrace: #{e.backtrace.first(5).join("\n")}", :error) if debug
      raise
    ensure
      browser&.quit
    end

    private

    def template_name
      # Use configured template path from engine
      template_path = Rails.application.config.social_construct.template_path
      "#{template_path}/#{self.class.name.demodulize.underscore}"
    end

    def layout_name
      # Check if a social cards layout exists
      layout_path = "layouts/#{Rails.application.config.social_construct.template_path}"
      if template_exists?(layout_path)
        layout_path
      else
        false
      end
    end

    def template_exists?(path)
      ApplicationController.view_paths.any? do |resolver|
        resolver.find_all(path, [], false, locale: [], formats: [:html], variants: [], handlers: [:erb]).any?
      end

    rescue
      false
    end

    def template_assigns
      {}
    end

    def attachment_data_url(attachment, variant_options = {})
      return nil unless attachment.attached?

      begin
        # Ensure high quality defaults
        options = {
          saver: {quality: 90, strip: true}
        }.deep_merge(variant_options)

        variant = attachment.variant(options)
        blob = variant.processed

        content_type = blob.content_type || "image/jpeg"
        image_data = blob.download
        file_size = image_data.bytesize

        # Check image size limitations
        # 2MB hard limit
        if file_size > 2_000_000
          log_debug("Image is #{file_size} bytes (#{file_size / 1024 / 1024}MB), exceeds 2MB data URL limit", :error)
          return nil
          # 500KB warning threshold
        elsif file_size > 500_000
          log_debug(
            "Image is #{file_size} bytes (#{file_size / 1024}KB), consider optimizing for better performance",
            :warn
          )
        end

        encoded_data = Base64.strict_encode64(image_data)
        log_debug("Image loaded: #{file_size} bytes (#{encoded_data.bytesize} bytes encoded)")

        "data:#{content_type};base64,#{encoded_data}"
      rescue => e
        log_debug("Failed to convert image to data URL: #{e.message}", :error)
        nil
      end
    end

    # Local font helper - converts font file to data URL
    def font_to_data_url(font_path)
      full_path = if font_path.start_with?("/")
        font_path
      else
        Rails.root.join("app", "assets", "fonts", font_path)
      end

      return nil unless File.exist?(full_path)

      begin
        font_data = File.read(full_path)
        file_size = font_data.bytesize

        # Check file size limitations
        # Most browsers have data URL limits around 2MB, but performance degrades after ~500KB
        # 2MB hard limit
        if file_size > 2_000_000
          log_debug(
            "Font file #{font_path} is #{file_size} bytes (#{file_size / 1024 / 1024}MB), exceeds 2MB data URL limit",
            :error
          )
          return nil
          # 500KB warning threshold
        elsif file_size > 500_000
          log_debug(
            "Font file #{font_path} is #{file_size} bytes (#{file_size / 1024}KB), consider optimizing for better performance",
            :warn
          )
        end

        content_type = font_content_type(full_path)
        encoded_data = Base64.strict_encode64(font_data)

        # Base64 encoding increases size by ~33%
        encoded_size = encoded_data.bytesize
        log_debug("Font #{font_path} loaded: #{file_size} bytes (#{encoded_size} bytes encoded)")

        "data:#{content_type};base64,#{encoded_data}"
      rescue => e
        log_debug("Failed to convert font to data URL: #{e.message}", :error)
        nil
      end
    end

    # Generate @font-face declaration for local fonts
    def generate_font_face(family_name, font_path, weight: "normal", style: "normal", display: "swap")
      data_url = font_to_data_url(font_path)
      return "" unless data_url

      <<~CSS
        @font-face {
          font-family: '#{family_name}';
          src: url('#{data_url}');
          font-weight: #{weight};
          font-style: #{style};
          font-display: #{display};
        }
      CSS
        .html_safe
    end

    def template_path
      Rails.application.config.social_construct.template_path
    end

    def log_debug(message, level = :info)
      return unless debug
      Rails.logger.send(level, "[SocialCard] #{message}")
    end

    # Local image helper - converts image file to data URL
    def image_data_url(image_path)
      full_path = if image_path.start_with?("/")
        image_path
      else
        Rails.root.join("app", "assets", "images", image_path)
      end

      return nil unless File.exist?(full_path)

      begin
        image_data = File.read(full_path)
        file_size = image_data.bytesize

        # Check file size limitations
        if file_size > 2_000_000
          log_debug(
            "Image file #{image_path} is #{file_size} bytes (#{file_size / 1024 / 1024}MB), exceeds 2MB data URL limit",
            :error
          )
          return nil
        elsif file_size > 500_000
          log_debug(
            "Image file #{image_path} is #{file_size} bytes (#{file_size / 1024}KB), consider optimizing for better performance",
            :warn
          )
        end

        content_type = image_content_type(full_path)
        encoded_data = Base64.strict_encode64(image_data)
        log_debug("Image #{image_path} loaded: #{file_size} bytes (#{encoded_data.bytesize} bytes encoded)")

        "data:#{content_type};base64,#{encoded_data}"
      rescue => e
        log_debug("Failed to convert image to data URL: #{e.message}", :error)
        nil
      end
    end

    # Determine MIME type for image files
    def image_content_type(image_path)
      extension = File.extname(image_path).downcase
      case extension
      when ".png"
        "image/png"
      when ".jpg", ".jpeg"
        "image/jpeg"
      when ".gif"
        "image/gif"
      when ".svg"
        "image/svg+xml"
      when ".webp"
        "image/webp"
      else
        # fallback
        "image/png"
      end
    end

    # Determine MIME type for font files
    def font_content_type(font_path)
      extension = File.extname(font_path).downcase
      case extension
      when ".woff2"
        "font/woff2"
      when ".woff"
        "font/woff"
      when ".ttf"
        "font/truetype"
      when ".otf"
        "font/opentype"
      when ".eot"
        "application/vnd.ms-fontobject"
      else
        # fallback
        "font/truetype"
      end
    end
  end
end

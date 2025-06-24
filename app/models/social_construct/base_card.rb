module SocialConstruct
  class BaseCard
    include ActionView::Helpers
    include Rails.application.routes.url_helpers

    attr_reader :width, :height

    # Class-level debug setting
    cattr_accessor :debug, default: false

    def initialize
      @width = 1200
      @height = 630
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
        window_size: [@width, @height]
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

      browser.set_viewport(width: @width, height: @height)

      # Wait for the page to fully load
      browser.network.wait_for_idle

      # Add extra wait for complex pages with large images
      sleep(0.5)

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

      screenshot = browser.screenshot(
        encoding: :binary,
        quality: 100,
        full: false
      )

      log_debug("Screenshot generated, size: #{screenshot.bytesize} bytes")

      # Check if screenshot might be blank (very small file size indicates mostly white/single color)
      # Less than 10KB usually means it's mostly one color
      if screenshot.bytesize < 10_000
        log_debug("Screenshot seems too small, might be blank. Retrying with delay...", :warn)

        # Wait a bit more and try again
        sleep(1)

        # Force a paint
        browser.execute(
          "document.body.style.display = 'none'; document.body.offsetHeight; document.body.style.display = 'flex';"
        )

        screenshot = browser.screenshot(
          encoding: :binary,
          quality: 100,
          full: false
        )
        log_debug("Retry screenshot size: #{screenshot.bytesize} bytes")
      end

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

    def image_to_data_url(attachment, variant_options = {})
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

        "data:#{content_type};base64,#{Base64.strict_encode64(image_data)}"
      rescue => e
        log_debug("Failed to convert image to data URL: #{e.message}", :error)
        nil
      end
    end

    def logo_data_url
      @logo_data_url ||= begin
        logo_path = Rails.root.join("app/assets/images/funnymost-logotype.png")
        if File.exist?(logo_path)
          logo_data = File.read(logo_path, mode: "rb")
          "data:image/png;base64,#{Base64.strict_encode64(logo_data)}"
        else
          nil
        end
      end
    end

    def log_debug(message, level = :info)
      return unless debug
      Rails.logger.send(level, "[SocialCard] #{message}")
    end
  end
end

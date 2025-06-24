module SocialConstruct
  module Controller
    extend ActiveSupport::Concern

    included do
      Mime::Type.register "image/png", :png unless Mime[:png]
    end

    # Render a social card as PNG with caching support
    def send_social_card(card, cache_key: nil, expires_in: 7.days, cache_in_development: false)
      # Build cache key if provided
      if cache_key && (!Rails.env.development? || cache_in_development)
        cache_key = Array(cache_key).join("-") if cache_key.is_a?(Array)

        png_data = Rails.cache.fetch(cache_key, expires_in: expires_in) do
          card.to_png
        end
      else
        png_data = card.to_png
      end

      # Set caching headers
      expires_in(1.day, public: true) unless Rails.env.development?

      send_data(
        png_data,
        type: "image/png",
        disposition: "inline",
        filename: "#{controller_name.singularize}-social-card.png"
      )
    rescue => e
      handle_social_card_error(e)
    end

    # Allow using render with social cards
    def render(*args)
      return super unless args.first.is_a?(SocialConstruct::BaseCard)

      card = args.first
      options = args.second || {}

      respond_to do |format|
        format.png { send_social_card(card, **options) }
        format.html { render(html: card.render.html_safe, layout: false) }
      end
    end

    private

    def handle_social_card_error(error)
      Rails.logger.error("Social card generation failed: #{error.message}")

      # Send a fallback 1x1 transparent PNG
      send_data(
        Base64.decode64(
          "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=="
        ),
        type: "image/png",
        disposition: "inline"
      )
    end
  end
end

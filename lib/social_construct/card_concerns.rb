module SocialConstruct
  module CardConcerns
    extend ActiveSupport::Concern

    included do
      # Allow the host app to override these methods
      class_attribute :logo_path, default: nil
    end

    def logo_data_url
      @logo_data_url ||= begin
        path = self.class.logo_path || Rails.root.join("app/assets/images/logo.png")
        if File.exist?(path)
          logo_data = File.read(path, mode: "rb")
          content_type = Marcel::MimeType.for(logo_data, name: File.basename(path))
          "data:#{content_type};base64,#{Base64.strict_encode64(logo_data)}"
        else
          nil
        end
      end
    end

    def template_path
      Rails.application.config.social_construct.template_path
    end

    def template_name
      # Use configured template path from engine
      "#{template_path}/#{self.class.name.demodulize.underscore}"
    end
  end
end

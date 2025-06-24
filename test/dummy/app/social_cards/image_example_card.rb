class ImageExampleCard < ApplicationSocialCard
  def initialize
    super
    @image_data_url = load_image_data_url
  end

  private

  def template_assigns
    {
      image_data_url: @image_data_url
    }
  end

  def load_image_data_url
    image_path = Rails.root.join("app", "assets", "images", "wavy_circles.png")
    if File.exist?(image_path)
      image_data = File.read(image_path)
      "data:image/png;base64,#{Base64.strict_encode64(image_data)}"
    else
      nil
    end
  end
end

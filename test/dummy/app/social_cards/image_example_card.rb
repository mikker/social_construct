class ImageExampleCard < ApplicationSocialCard
  def template_assigns
    {
      image_data_url: image_data_url("wavy_circles.png")
    }
  end
end

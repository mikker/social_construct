class EverythingCard < ApplicationSocialCard
  def initialize(
    title: "Everything Example",
    subtitle: "All features combined",
    body: "Images, remote fonts, and local fonts together"
  )
    @title = title
    @subtitle = subtitle
    @body = body
    @custom_font_css = generate_font_face(
      "Recursive",
      "Recursive_VF_1.085--subset-GF_latin_basic.woff2",
      weight: "300 1000"
    )
  end

  def template_assigns
    {
      title: @title,
      subtitle: @subtitle,
      body: @body,
      custom_font_css: @custom_font_css,
      image_data_url: image_data_url("wavy_circles.png")
    }
  end
end

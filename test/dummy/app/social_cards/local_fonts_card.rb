class LocalFontsCard < ApplicationSocialCard
  def initialize
    @custom_font_css = generate_font_face(
      "custom-font-name",
      "Recursive_VF_1.085--subset-GF_latin_basic.woff2",
      weight: "300 1000"
    )
  end

  def template_assigns
    {
      custom_font_css: @custom_font_css
    }
  end
end

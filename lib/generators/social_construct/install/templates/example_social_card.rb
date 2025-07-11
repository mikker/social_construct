class ExampleSocialCard < ApplicationSocialCard
  def initialize(title: "Hello World", subtitle: nil, background_color: "#1a1a1a")
    @title = title
    @subtitle = subtitle
    @background_color = background_color
  end

  private

  def template_assigns
    {
      title: @title,
      subtitle: @subtitle,
      background_color: @background_color
    }
  end
end

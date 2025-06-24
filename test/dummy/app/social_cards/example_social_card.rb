class ExampleSocialCard < ApplicationSocialCard
  attr_reader :title, :description, :color_scheme
  
  def initialize(title: "Example Social Card", description: "This is a test social card", color_scheme: "gradient-purple")
    super()
    @title = title
    @description = description
    @color_scheme = color_scheme
  end
  
  private
  
  def template_assigns
    {
      title: title,
      description: description,
      color_scheme: color_scheme,
      timestamp: Time.current.strftime("%B %d, %Y at %I:%M %p")
    }
  end
end
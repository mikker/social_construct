class ExampleSocialCardPreview
  def default
    ExampleSocialCard.new(
      title: "Welcome to SocialConstruct",
      subtitle: "Beautiful social cards for your Rails app"
    )
  end

  def dark_theme
    ExampleSocialCard.new(
      title: "Dark Theme Example",
      subtitle: "Perfect for modern applications",
      background_color: "#0a0a0a"
    )
  end

  def colorful
    ExampleSocialCard.new(
      title: "Colorful Background",
      subtitle: "Make your cards stand out",
      background_color: "#6366f1"
    )
  end

  def long_title
    ExampleSocialCard.new(
      title: "This is a very long title that demonstrates how text wrapping works in social cards",
      subtitle: "Subtitle remains readable"
    )
  end

  def no_subtitle
    ExampleSocialCard.new(
      title: "Simple and Clean"
    )
  end
end

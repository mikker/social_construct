require "test_helper"

class NavigationTest < ActionDispatch::IntegrationTest
  test "preview interface is accessible in development" do
    get "/rails/social_cards/previews"
    assert_response :success
    assert_select "h1", "Social Card Previews"
  end
  
  test "preview interface shows available previews" do
    # Create a preview class
    preview_dir = Rails.root.join("app/social_cards/previews")
    FileUtils.mkdir_p(preview_dir)
    
    File.write(preview_dir.join("navigation_preview.rb"), <<~RUBY)
      class NavigationPreview
        def homepage
          TestCard.new(title: "Welcome")
        end
      end
      
      class TestCard < SocialConstruct::BaseCard
        attr_accessor :title
        def initialize(title:)
          super()
          @title = title
        end
        
        private
        
        def template_assigns
          { title: @title, card: self }
        end
      end
    RUBY
    
    # Create template
    template_dir = Rails.root.join("app/views/social_cards")
    FileUtils.mkdir_p(template_dir)
    File.write(template_dir.join("test_card.html.erb"), "<h1><%= title %></h1>")
    
    load preview_dir.join("navigation_preview.rb")
    
    get "/rails/social_cards/previews"
    assert_response :success
    assert_select "a[href=?]", "/rails/social_cards/previews/navigation", text: "navigation"
    
    # Navigate to specific preview
    get "/rails/social_cards/previews/navigation"
    assert_response :success
    assert_select "h1", text: /Navigation Preview/
    assert_select "h2", "homepage"
    
    # View the actual card
    get "/rails/social_cards/previews/navigation/homepage.png"
    assert_response :success
    assert_equal "image/png", response.content_type
  ensure
    FileUtils.rm_rf(preview_dir)
    FileUtils.rm_rf(template_dir)
    Object.send(:remove_const, :NavigationPreview) if defined?(NavigationPreview)
    Object.send(:remove_const, :TestCard) if defined?(TestCard)
  end
end

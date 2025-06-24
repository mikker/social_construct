require "test_helper"

class SocialCardGenerationTest < ActionDispatch::IntegrationTest
  class ArticleCard < SocialConstruct::BaseCard
    attr_accessor :title, :description, :author, :published_at
    
    def initialize(article)
      super()
      @title = article[:title]
      @description = article[:description]
      @author = article[:author]
      @published_at = article[:published_at]
    end
  end
  
  class ArticlesController < ActionController::Base
    include SocialConstruct::Controller
    
    def show
      article = {
        title: params[:title] || "Test Article",
        description: "This is a test article for social cards",
        author: "Test Author",
        published_at: Time.current
      }
      
      @card = ArticleCard.new(article)
      
      respond_to do |format|
        format.html { render plain: "Article page" }
        format.png { send_social_card(@card, cache_key: ["article", params[:id]]) }
      end
    end
  end
  
  setup do
    # Setup routes
    Rails.application.routes.draw do
      get "/articles/:id", to: "social_card_generation_test/articles#show", as: :article
      mount SocialConstruct::Engine => "/rails"
    end
    
    # Create template
    @template_dir = Rails.root.join("app/views/social_cards")
    FileUtils.mkdir_p(@template_dir)
    
    File.write(@template_dir.join("article_card.html.erb"), <<~ERB)
      <!DOCTYPE html>
      <html>
        <head>
          <style>
            body {
              margin: 0;
              font-family: -apple-system, sans-serif;
              width: 1200px;
              height: 630px;
              display: flex;
              align-items: center;
              justify-content: center;
              background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
              color: white;
            }
            .content {
              text-align: center;
              padding: 40px;
            }
            h1 {
              font-size: 48px;
              margin: 0 0 20px 0;
            }
            p {
              font-size: 24px;
              opacity: 0.9;
            }
            .author {
              font-size: 20px;
              opacity: 0.7;
              margin-top: 40px;
            }
          </style>
        </head>
        <body>
          <div class="content">
            <h1><%= @title %></h1>
            <p><%= @description %></p>
            <div class="author">By <%= @author %></div>
          </div>
        </body>
      </html>
    ERB
    
    Rails.cache.clear
  end
  
  teardown do
    FileUtils.rm_rf(@template_dir)
    Rails.cache.clear
    Rails.application.reload_routes!
  end
  
  test "full flow: controller generates and caches social card" do
    # First request - should generate card
    get "/articles/123.png"
    
    assert_response :success
    assert_equal "image/png", response.content_type
    assert response.body.size > 1000 # PNG should be reasonably sized
    
    # Verify it's a valid PNG
    assert response.body.start_with?("\x89PNG")
    
    # Second request - should use cache
    original_body = response.body
    get "/articles/123.png"
    
    assert_response :success
    assert_equal original_body, response.body # Should be identical from cache
  end
  
  test "different articles generate different cards" do
    get "/articles/123.png?title=First+Article"
    first_card = response.body
    
    get "/articles/456.png?title=Second+Article"
    second_card = response.body
    
    refute_equal first_card, second_card
  end
  
  test "HTML format returns regular response" do
    get "/articles/123"
    
    assert_response :success
    assert_equal "text/html", response.content_type.split(";").first
    assert_equal "Article page", response.body
  end
  
  test "social card with custom dimensions" do
    # Create a custom card class
    custom_card_class = Class.new(SocialConstruct::BaseCard) do
      def template_name
        "custom_dimensions"
      end
    end
    
    File.write(@template_dir.join("custom_dimensions.html.erb"), <<~ERB)
      <div style="width: 800px; height: 418px; background: #f0f0f0; display: flex; align-items: center; justify-content: center;">
        <h1>Custom Size Card</h1>
      </div>
    ERB
    
    controller = Class.new(ActionController::Base) do
      include SocialConstruct::Controller
      
      def show
        card = custom_card_class.new
        send_social_card(card)
      end
    end
    
    Rails.application.routes.draw do
      get "/custom", to: controller.action(:show)
      mount SocialConstruct::Engine => "/rails"
    end
    
    get "/custom"
    assert_response :success
    assert_equal "image/png", response.content_type
  end
end
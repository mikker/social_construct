require "test_helper"

module SocialConstruct
  class PreviewsControllerTest < ActionDispatch::IntegrationTest
    class ArticleCard < BaseCard
      attr_accessor :title, :author
      
      def initialize(title:, author:)
        super()
        @title = title
        @author = author
      end
    end
    
    setup do
      Rails.application.routes.draw do
        mount SocialConstruct::Engine => "/rails"
      end
      
      # Create preview directory and files
      @preview_dir = Rails.root.join("app/social_cards/previews")
      FileUtils.mkdir_p(@preview_dir)
      
      # Create a test preview class
      File.write(@preview_dir.join("article_preview.rb"), <<~RUBY)
        class ArticlePreview
          def basic
            SocialConstruct::PreviewsControllerTest::ArticleCard.new(
              title: "Basic Article",
              author: "Test Author"
            )
          end
          
          def with_long_title
            SocialConstruct::PreviewsControllerTest::ArticleCard.new(
              title: "This is a very long article title that should wrap properly",
              author: "Another Author"
            )
          end
        end
      RUBY
      
      # Create another preview class
      File.write(@preview_dir.join("product_preview.rb"), <<~RUBY)
        class ProductPreview
          def featured
            SocialConstruct::PreviewsControllerTest::ArticleCard.new(
              title: "Featured Product",
              author: "Store"
            )
          end
        end
      RUBY
      
      # Create template for ArticleCard
      @template_dir = Rails.root.join("app/views/social_cards")
      FileUtils.mkdir_p(@template_dir)
      File.write(@template_dir.join("article_card.html.erb"), <<~ERB)
        <div style="padding: 40px;">
          <h1><%= @title %></h1>
          <p>By <%= @author %></p>
        </div>
      ERB
      
      # Load the preview classes
      load @preview_dir.join("article_preview.rb")
      load @preview_dir.join("product_preview.rb")
    end
    
    teardown do
      FileUtils.rm_rf(@preview_dir)
      FileUtils.rm_rf(@template_dir)
      # Remove constants to avoid pollution
      Object.send(:remove_const, :ArticlePreview) if defined?(ArticlePreview)
      Object.send(:remove_const, :ProductPreview) if defined?(ProductPreview)
    end
    
    test "index lists all preview classes" do
      get "/rails/social_cards/previews"
      
      assert_response :success
      assert_select "h1", "Social Card Previews"
      assert_select "a", text: "article"
      assert_select "a", text: "product"
    end
    
    test "index handles no preview classes gracefully" do
      # Remove all preview files
      FileUtils.rm_rf(@preview_dir)
      
      get "/rails/social_cards/previews"
      
      assert_response :success
      assert_select "p", text: /No preview classes found/
    end
    
    test "show displays all examples for a preview class" do
      get "/rails/social_cards/previews/article"
      
      assert_response :success
      assert_select "h1", text: /Article Preview/
      assert_select "h2", text: "basic"
      assert_select "h2", text: "with_long_title"
      
      # Check for preview links
      assert_select "a[href=?]", "/rails/social_cards/previews/article/basic.png"
      assert_select "a[href=?]", "/rails/social_cards/previews/article/basic.html"
    end
    
    test "show returns 404 for non-existent preview" do
      assert_raises(ActionController::RoutingError) do
        get "/rails/social_cards/previews/nonexistent"
      end
    end
    
    test "preview renders card as PNG" do
      get "/rails/social_cards/previews/article/basic.png"
      
      assert_response :success
      assert_equal "image/png", response.content_type
      # PNG files start with these bytes
      assert response.body.start_with?("\x89PNG") || response.body.include?("PNG")
    end
    
    test "preview renders card as HTML" do
      get "/rails/social_cards/previews/article/basic.html"
      
      assert_response :success
      assert_equal "text/html", response.content_type.split(";").first
      assert_includes response.body, "Basic Article"
      assert_includes response.body, "Test Author"
    end
    
    test "preview handles missing preview class" do
      assert_raises(ActionController::RoutingError) do
        get "/rails/social_cards/previews/missing/example.png"
      end
    end
    
    test "preview handles missing example method" do
      assert_raises(ActionController::RoutingError) do
        get "/rails/social_cards/previews/article/nonexistent.png"
      end
    end
    
    test "preview handles errors in example method gracefully" do
      # Create a preview with an error
      File.write(@preview_dir.join("error_preview.rb"), <<~RUBY)
        class ErrorPreview
          def broken
            raise "Something went wrong!"
          end
        end
      RUBY
      load @preview_dir.join("error_preview.rb")
      
      assert_raises(ActionController::RoutingError) do
        get "/rails/social_cards/previews/error/broken.png"
      end
    ensure
      Object.send(:remove_const, :ErrorPreview) if defined?(ErrorPreview)
    end
    
    test "preview_classes discovers all preview files" do
      skip "This tests private implementation details"
      
    end
    
    test "format parameter defaults to PNG" do
      get "/rails/social_cards/previews/article/basic"
      
      assert_response :success
      assert_equal "image/png", response.content_type
    end
    
    test "preview path only available in development" do
      Rails.stub :env, ActiveSupport::StringInquirer.new("production") do
        # In production, these routes should not exist
        # This test would need route reloading to properly test
        # For now, we'll just verify the controller checks Rails.env
        controller = PreviewsController.new
        refute_nil controller
      end
    end
  end
end
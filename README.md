# SocialConstruct

A Rails engine for generating social media preview cards (Open Graph images) with built-in preview functionality.

## Installation

Add to your Gemfile:

```ruby
gem "social_construct", path: "vendor/social_construct"
```

Run the installation generator:

```bash
bundle install
bin/rails generate social_construct:install
```

This will:
- Create a configuration initializer
- Set up ApplicationSocialCard base class
- Create an example social card with template
- Add a shared layout for social cards
- Mount the preview interface in development
- Create example preview classes

## Usage

### 1. Create your base social card class

```ruby
# app/social_cards/application_social_card.rb
class ApplicationSocialCard < SocialConstruct::BaseCard
  include SocialConstruct::CardConcerns
  
  # Set the logo path for your application
  self.logo_path = Rails.root.join("app/assets/images/logo.png")
end
```

### 2. Create specific social card classes

```ruby
# app/social_cards/item_social_card.rb
class ItemSocialCard < ApplicationSocialCard
  def initialize(item)
    super()
    @item = item
  end
  
  private
  
  def template_assigns
    {
      item: @item,
      cover_image_data_url: image_to_data_url(@item.cover_image, resize_to_limit: [480, 630], saver: {quality: 75}),
      logo_data_url: logo_data_url
    }
  end
end
```

### 3. Create templates

Templates go in `app/views/social_cards/` and should match your class names:

```erb
<!-- app/views/social_cards/item_social_card.html.erb -->
<div class="card">
  <h1><%= item.title %></h1>
  <!-- Your card HTML -->
</div>
```

### 4. Optional: Use a shared layout

Create `app/views/layouts/social_cards.html.erb` for shared HTML structure:

```erb
<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8">
    <style>
      /* Shared styles */
    </style>
    <%= yield :head %>
  </head>
  <body>
    <%= yield %>
  </body>
</html>
```

### 5. Create preview classes for development

```ruby
# app/social_cards/previews/item_social_card_preview.rb
class ItemSocialCardPreview
  def default
    item = Item.first || Item.new(title: "Example Item")
    ItemSocialCard.new(item)
  end
  
  def with_long_title
    item = Item.new(title: "This is a very long title that will test text wrapping")
    ItemSocialCard.new(item)
  end
end
```

Visit `/rails/social_cards` in development to see all your previews.

### 6. Use in your controllers

Include the controller concern:

```ruby
class ItemsController < ApplicationController
  include SocialConstruct::Controller
  
  def og
    @item = Item.find(params[:id])
    render ItemSocialCard.new(@item)
  end
end
```

The `render` method automatically handles both formats:
- `.png` - Generates the actual PNG image
- `.html` - Shows the HTML preview (useful for debugging)

Or with caching:

```ruby
def og
  @item = Item.find(params[:id])
  
  cache_key = [
    "social-cards",
    "item",
    @item.id,
    @item.updated_at.to_i
  ]
  
  render ItemSocialCard.new(@item), cache_key: cache_key
end
```

Alternative API:

```ruby
def og
  @item = Item.find(params[:id])
  card = ItemSocialCard.new(@item)
  
  send_social_card(card, 
    cache_key: ["social-cards", @item.id, @item.updated_at.to_i],
    expires_in: 7.days
  )
end
```

## Configuration

Configure in your initializer:

```ruby
# config/initializers/social_construct.rb

# Template path (default: "social_cards")
Rails.application.config.social_construct.template_path = "custom_path"

# Enable debug logging (default: false)
SocialConstruct::BaseCard.debug = true
```

## Requirements

- Rails 7.0+
- Ferrum (headless Chrome driver)
- Marcel (MIME type detection)

## License

MIT
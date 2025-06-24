<img src="https://s3.brnbw.com/Stack-C9apVxz8Pg.webp" width="600">

- Design using HTML/CSS
- Supports images, fonts, caching, ...
- Built-in previews in development (like mailers)
- Only requirement is Chrome(ium)

## Example

Create a card class:

```ruby
class PostSocialCard < ApplicationSocialCard
  def initialize(post)
    @post = post
  end

  def template_assigns
    {
      title: @post.title,
      author: @post.author_name,
      avatar: attachment_data_url(@post.author.avatar)
    }
  end
end
```

Create a template:

```erb
<!-- app/views/social_cards/post_social_card.html.erb -->

<div class="card">
  <img src="<%= avatar %>" class="logo">
  <h1><%= title %></h1>
  <p>by <%= author %></p>
</div>
```

Add a controller action:

```ruby
class PostsController < ApplicationController
  include SocialConstruct::Controller

  # ...

  def social_image
    @post = Post.find(params[:id])

    send_social_card(
      PostSocialCard.new(@post),
      cache_key: [@post.id, @post.updated_at]
    )
  end
end
```

## Setup

```sh
$ bundle add social_construct && bundle install
$ bin/rails generate social_construct:install
```

## Images

Convert ActiveStorage attachments to Base64 `data://` URLs:

```ruby
def template_assigns
  {
    cover_image: attachment_data_url(@post.cover_image),
    avatar: attachment_data_url(@post.author.avatar, resize_to_limit: [200, 200])
  }
end
```

## Fonts

### Remote fonts

Just import them normally and they should work.

```erb
<style>
  @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;700&display=swap');
  body { font-family: 'Inter', sans-serif; }
</style>
```

### Local fonts

Store fonts in `app/assets/fonts/` and embed as `data://` URLs:

```ruby
class LocalFontsCard < ApplicationSocialCard
  def template_assigns
    {
      custom_font_css: generate_font_face(
        "custom-font-name",
        "Recursive_VF_1.085--subset-GF_latin_basic.woff2",
        weight: "300 1000"
      )
    }
  end
end
```

And include in template:

```erb
<style>
  <%= custom_font_css %>

  body {
    font-family: 'custom-font-name', sans-serif;
  }
</style>
```

## Previews

Mount the preview engine:

```ruby
Rails.application.routes.draw do
  if Rails.env.development?
    mount(SocialConstruct::Engine => "/rails/social_cards")
  end
end
```

Create preview classes:

```ruby
# app/social_cards/previews/post_social_card_preview.rb
class PostSocialCardPreview
  def default
    PostSocialCard.new(Post.first)
  end

  def long_title
    post = Post.new(title: "A very long title that demonstrates text wrapping behavior")
    PostSocialCard.new(post)
  end
end
```

Visit `http://localhost:3000/rails/social_cards` to preview all cards.

## License

MIT


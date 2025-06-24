SocialConstruct::Engine.routes.draw do
  # Preview routes for development
  unless Rails.env.production?
    resources(:previews, only: [:index, :show], param: :preview_name) do
      member do
        get(":example_name", action: :preview, as: :example)
      end
    end
  end
end

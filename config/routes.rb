SocialConstruct::Engine.routes.draw do
  resources(:previews, only: [:index, :show], param: :preview_name) do
    member do
      get(":example_name", action: :preview, as: :example)
    end
  end

  root(to: redirect("previews"))
end

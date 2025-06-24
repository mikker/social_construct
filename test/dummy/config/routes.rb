Rails.application.routes.draw do
  # Mount the engine in development for preview functionality
  if Rails.env.development? || Rails.env.test?
    mount(SocialConstruct::Engine => "/rails/social_cards")
  end

  get("up" => "rails/health#show", :as => :rails_health_check)

  root("home#index")
end

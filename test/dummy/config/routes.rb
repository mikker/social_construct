Rails.application.routes.draw do
  if Rails.env.development? || Rails.env.test?
    mount(SocialConstruct::Engine, at: "/rails/social_cards")
  end

  get("up" => "rails/health#show", :as => :rails_health_check)

  root("home#index")
end

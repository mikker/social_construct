class ApplicationSocialCard < SocialConstruct::BaseCard
  include SocialConstruct::CardConcerns

  # Set the logo path for your application
  # Update this to point to your actual logo file
  self.logo_path = Rails.root.join("app/assets/images/logo.png")

  # You can add any shared methods or configuration here
  # that will be available to all your social card classes
end

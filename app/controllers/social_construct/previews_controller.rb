module SocialConstruct
  class PreviewsController < ActionController::Base
    def index
      @preview_classes = find_preview_classes
    end

    def show
      @preview_class = find_preview_class(params[:preview_name])
      @preview_name = params[:preview_name]

      unless @preview_class
        redirect_to(previews_path, alert: "Preview not found")
        return
      end

      @examples = @preview_class.instance_methods(false).sort
    end

    def preview
      preview_class = find_preview_class(params[:preview_name])
      example_name = params[:example_name]

      unless preview_class && example_name
        redirect_to(previews_path, alert: "Preview not found")
        return
      end

      @card = preview_class.new.send(example_name)

      respond_to do |format|
        format.html { render(html: @card.render.html_safe, layout: false) }
        format.png { send_data(@card.to_png, type: "image/png", disposition: "inline") }
      end
    end

    private

    def find_preview_classes
      # Look for preview classes in the host app
      preview_path = Rails.root.join("app/social_cards/previews")
      return [] unless preview_path.exist?

      Dir[preview_path.join("*_preview.rb")]
        .map do |file|
          require_dependency(file)
          class_name = File.basename(file, ".rb").camelize
          class_name.constantize if Object.const_defined?(class_name)
        end
        .compact
    end

    def find_preview_class(name)
      return nil unless name

      class_name = "#{name.camelize}Preview"
      class_name.constantize if Object.const_defined?(class_name)
    rescue NameError
      nil
    end
  end
end

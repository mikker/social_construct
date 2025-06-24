module SocialConstruct
  class PreviewsController < ActionController::Base
    before_action :ensure_previews_enabled

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
      return [] unless (paths = Rails.application.config.social_construct.preview_paths)

      pp(paths)

      paths
        .map do |path|
          next [] unless path.exist?

          glob = path.join("*_preview.rb")

          Dir[glob]
            .map do |file|
              require_dependency(file)
              class_name = File.basename(file, ".rb").camelize
              class_name.constantize if Object.const_defined?(class_name)
            end
            .compact
        end
        .flatten
    end

    def find_preview_class(name)
      return nil unless name

      class_name = "#{name.camelize}Preview"
      class_name.constantize if Object.const_defined?(class_name)
    rescue NameError
      nil
    end

    def ensure_previews_enabled
      unless Rails.application.config.social_construct.show_previews
        raise ActionController::RoutingError, "Social card previews are disabled"
      end
    end
  end
end

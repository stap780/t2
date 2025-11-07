class ApplicationController < ActionController::Base
  include Authentication
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :set_locale

  private
  
    def set_locale
      requested = params[:locale]
      available = I18n.available_locales.map(&:to_s)
      I18n.locale = available.include?(requested) ? requested : I18n.default_locale
    end

    def default_url_options
      params[:locale].present? ? { locale: I18n.locale } : {}
    end

    def ensure_admin
      unless Current.user&.admin?
        flash[:alert] = t('access_denied', default: 'Access denied. Admin privileges required.')
        redirect_to dashboard_path
      end
    end

    # Hotwire helper to update the flash container via turbo_stream
    def render_turbo_flash
      turbo_stream.replace("flash", partial: "shared/flash")
    end

    # Helper to close offcanvas and show flash message
    def turbo_close_offcanvas_flash
      [
        render_turbo_flash,
        turbo_stream.update(:offcanvas, "")
      ]
    end
end

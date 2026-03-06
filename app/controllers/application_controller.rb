class ApplicationController < ActionController::Base
  include Authentication
  # Only allow modern browsers for UI; skip for external endpoints (webhooks, export files, health)
  before_action :check_browser_version

  before_action :set_locale
  before_action :set_active_storage_url_options

  # Метод для получения текущего пользователя (используется audited и доступен во views)
  def current_user
    Current.user
  end
  helper_method :current_user

  private

    def check_browser_version
      return if external_request?
      allow_browser(
        versions: :modern,
        block: -> { render file: Rails.root.join("public/406-unsupported-browser.html"), layout: false, status: :not_acceptable }
      )
    end

    def external_request?
      request.path.start_with?("/api/webhooks/", "/api/moisklad/") ||
        request.path.match?(%r{^/exports/export-\d+}) ||
        request.path == "/up"
    end

    def set_locale
      requested = params[:locale]
      available = I18n.available_locales.map(&:to_s)
      I18n.locale = available.include?(requested) ? requested : I18n.default_locale
    end

    def set_active_storage_url_options
      ActiveStorage::Current.url_options = {
        host: request.base_url,
        protocol: request.protocol
      }
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

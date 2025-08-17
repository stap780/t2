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
end

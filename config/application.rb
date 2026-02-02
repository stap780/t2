require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module T2
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
  # Set application time zone (used by Time.zone and view formatting)
  config.time_zone = "Europe/Moscow"
  # Keep database timestamps in UTC for consistency
  config.active_record.default_timezone = :utc
  # Localization
  config.i18n.available_locales = [:ru, :en]
  config.i18n.default_locale = :ru

  # Сессия в БД (таблица ar_sessions), чтобы не упираться в лимит cookie 4 KB
  config.session_store :active_record_store, key: "_t2_session"

  # config.eager_load_paths << Rails.root.join("extras")
  end
end

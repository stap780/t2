# frozen_string_literal: true

module Insales
  module Config
    CREDENTIALS = [
      {
        api_key: Rails.application.credentials.dig(:insales, :key1),
        api_password: Rails.application.credentials.dig(:insales, :pass1),
        api_link: "dizauto.myinsales.ru"
      },
      {
        api_key: Rails.application.credentials.dig(:insales, :key2),
        api_password: Rails.application.credentials.dig(:insales, :pass2),
        api_link: "dizauto.myinsales.ru"
      },
      {
        api_key: Rails.application.credentials.dig(:insales, :key3),
        api_password: Rails.application.credentials.dig(:insales, :pass3),
        api_link: "dizauto.myinsales.ru"
      },
      {
        api_key: Rails.application.credentials.dig(:insales, :key4),
        api_password: Rails.application.credentials.dig(:insales, :pass4),
        api_link: "dizauto.myinsales.ru"
      }
    ].freeze
  end
end

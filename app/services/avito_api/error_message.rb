# frozen_string_literal: true

module AvitoApi
  # Перевод кодов ошибок интеграции Avito для flash и UI.
  class ErrorMessage
    I18N_SCOPE = "avito_api.errors"
    MOYSKLAD_ORDER_PREFIX = /\AMS order #(\d+): (.+)\z/

    def self.translate(error)
      error = error.to_s
      if (match = error.match(MOYSKLAD_ORDER_PREFIX))
        I18n.t(
          "#{I18N_SCOPE}.moysklad_order",
          order_id: match[1],
          message: translate(match[2])
        )
      else
        I18n.t("#{I18N_SCOPE}.#{error}", default: error)
      end
    end

    def self.translate_list(errors, limit: 3)
      errors.first(limit).map { |error| translate(error) }.join("; ")
    end
  end
end

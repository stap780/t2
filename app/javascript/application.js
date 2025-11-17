// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

import "trix"
import "@rails/actiontext"

// Fancybox initialization
import { Fancybox } from "@fancyapps/ui"

function initFancybox() {
  Fancybox.bind("[data-fancybox]", {
    Toolbar: {
      display: {
        left: ["infobar"],
        middle: [],
        right: ["slideshow", "download", "thumbs", "close"],
      },
    },
  })
}

// Custom Turbo Stream Actions
// set_unchecked: снимает выделение со всех чекбоксов, найденных по селектору из атрибута targets
// StreamActions доступен через глобальный объект Turbo после импорта @hotwired/turbo-rails
document.addEventListener("turbo:load", function() {
  // Turbo доступен глобально после импорта @hotwired/turbo-rails
  if (typeof Turbo !== "undefined" && Turbo.StreamActions) {
    Turbo.StreamActions.set_unchecked = function() {
      this.targetElements.forEach((element) => {
        element.checked = false
      })
    }
  }
}, { once: true })

document.addEventListener("DOMContentLoaded", initFancybox)
document.addEventListener("turbo:load", initFancybox)

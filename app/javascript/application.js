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


document.addEventListener("DOMContentLoaded", initFancybox)
document.addEventListener("turbo:load", initFancybox)

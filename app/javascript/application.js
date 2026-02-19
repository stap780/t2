// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

import "trix"
import "@rails/actiontext"

// // Fancybox initialization
// import { Fancybox } from "@fancyapps/ui"

// function initFancybox() {
//   Fancybox.bind("[data-fancybox]", {
//     Toolbar: {
//       display: {
//         left: ["infobar"],
//         middle: [],
//         right: ["slideshow", "download", "thumbs", "close"],
//       },
//     },
//   })
// }

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
    Turbo.StreamActions.scroll_to = function () {
      const targetId = this.target || this.getAttribute("target");
      const scroll = () => {
        const element = document.getElementById(targetId);
        if (element) {
          element.scrollIntoView({ behavior: "smooth" });
        }
      };
      requestAnimationFrame(scroll);
    };
  }
}, { once: true })

// document.addEventListener("DOMContentLoaded", initFancybox)
// document.addEventListener("turbo:load", initFancybox)

// Сохранение скролла при обновлении статусов (update_status, bulk_update)
function isStatusUpdateRequest(url) {
  const s = typeof url === 'string' ? url : url?.href || ''
  return s.includes('update_status') || s.includes('bulk_update')
}

function getScrollContainer() {
  return document.querySelector('main.overflow-y-auto') || document.documentElement
}

function saveScroll() {
  const el = getScrollContainer()
  window._savedScrollTop = el === document.documentElement ? window.scrollY : el.scrollTop
}

function restoreScroll() {
  if (window._savedScrollTop == null) return
  const el = getScrollContainer()
  if (el === document.documentElement) {
    window.scrollTo({ top: window._savedScrollTop, left: 0, behavior: 'auto' })
  } else {
    el.scrollTop = window._savedScrollTop
  }
}

// Сохраняем скролл при submit формы с turbo_preserve_scroll (надёжнее, чем по URL)
document.addEventListener('submit', (event) => {
  const form = event.target
  if (form?.dataset?.turboPreserveScroll === 'true') {
    saveScroll()
    document.activeElement?.blur?.()
    startScrollGuard()
  }
}, true)

document.addEventListener('turbo:before-fetch-request', (event) => {
  const url = event.detail?.fetchRequest?.url ?? event.detail?.url
  if (isStatusUpdateRequest(url) && window._savedScrollTop == null) {
    saveScroll()
    startScrollGuard()
  }
})

// Восстанавливаем скролл
document.addEventListener('turbo:after-stream-render', () => {
  restoreScroll()
  ;[0, 50, 100, 200, 400].forEach((ms) => setTimeout(restoreScroll, ms))
  setTimeout(() => { window._savedScrollTop = null }, 500)
})

document.addEventListener('turbo:fetch-request-end', restoreScroll)

// Принудительно удерживаем скролл каждые 16ms в течение 600ms
function startScrollGuard() {
  if (window._scrollGuard) return
  const el = getScrollContainer()
  const target = window._savedScrollTop
  if (target == null) return
  window._scrollGuard = setInterval(() => {
    if (window._savedScrollTop == null) {
      clearInterval(window._scrollGuard)
      window._scrollGuard = null
      return
    }
    const current = el === document.documentElement ? window.scrollY : el.scrollTop
    if (Math.abs(current - target) > 5) {
      restoreScroll()
    }
  }, 16)
  setTimeout(() => {
    clearInterval(window._scrollGuard)
    window._scrollGuard = null
  }, 600)
}
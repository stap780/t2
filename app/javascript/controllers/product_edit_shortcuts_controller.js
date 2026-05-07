import { Controller } from "@hotwired/stimulus"

// Горячие клавиши на странице товара: Ctrl+Alt+R / ⌘+⌥+R — заполнить из Detal,
// Ctrl+Alt+U / ⌘+⌥+U — диалог загрузки изображений. Используем event.code — не зависит от раскладки.
export default class extends Controller {
  static targets = ["refill", "upload"]

  connect() {
    this.boundKeydown = this.onKeydown.bind(this)
    window.addEventListener("keydown", this.boundKeydown, true)
  }

  disconnect() {
    window.removeEventListener("keydown", this.boundKeydown, true)
  }

  onKeydown(event) {
    if (event.repeat) return
    if (this.isTypingContext(event.target)) return

    const primary = event.ctrlKey || event.metaKey
    if (!primary || !event.altKey) return
    if (event.shiftKey) return

    if (event.code === "KeyR") {
      if (!this.hasRefillTarget) return
      event.preventDefault()
      event.stopPropagation()
      this.refillTarget.click()
      return
    }

    if (event.code === "KeyU") {
      if (!this.hasUploadTarget) return
      event.preventDefault()
      event.stopPropagation()
      this.uploadTarget.click()
      return
    }
  }

  isTypingContext(el) {
    if (!el || typeof el.closest !== "function") return false
    const tag = el.tagName
    if (tag === "INPUT" || tag === "TEXTAREA" || tag === "SELECT") return true
    if (el.isContentEditable) return true
    if (el.closest("trix-editor")) return true
    return false
  }
}

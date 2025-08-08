import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { message: String, type: String }

  connect() {
    this.show()
  }

  show() {
    this.element.classList.remove("translate-x-full", "opacity-0")
    this.element.classList.add("translate-x-0", "opacity-100")
    
    // Auto-hide after 5 seconds
    setTimeout(() => {
      this.hide()
    }, 5000)
  }

  hide() {
    this.element.classList.add("translate-x-full", "opacity-0")
    this.element.classList.remove("translate-x-0", "opacity-100")
    
    // Remove element after animation
    setTimeout(() => {
      this.element.remove()
    }, 300)
  }

  close() {
    this.hide()
  }
}

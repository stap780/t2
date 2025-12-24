import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="debounce"
export default class extends Controller {
  static targets = ["form"]
  
  connect() {
    // Инициализация контроллера
  }
  
  search() {
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => {
      this.formTarget.requestSubmit()
    }, 500)
  }

  clear() {
    this.formTarget.reset()
    this.formTarget.requestSubmit()
  }
}


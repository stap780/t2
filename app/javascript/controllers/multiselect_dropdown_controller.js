import { Controller } from "@hotwired/stimulus"

// Выпадающий multiselect с чекбоксами (Tailwind). Кнопка показывает плейсхолдер или «N выбрано».
export default class extends Controller {
  static targets = ["panel", "button", "label"]

  connect() {
    this.boundClickOutside = this.clickOutside.bind(this)
    document.addEventListener("click", this.boundClickOutside)
    this.updateButtonLabel()
  }

  disconnect() {
    document.removeEventListener("click", this.boundClickOutside)
  }

  toggle(event) {
    event.stopPropagation()
    this.panelTarget.classList.toggle("hidden")
  }

  clickOutside(event) {
    if (this.hasPanelTarget && !this.element.contains(event.target)) {
      this.panelTarget.classList.add("hidden")
    }
  }

  updateButtonLabel() {
    const checked = this.element.querySelectorAll('input[type="checkbox"]:checked')
    const placeholder = this.buttonTarget?.dataset?.placeholder || "Выберите..."
    const text = checked.length === 0 ? placeholder : `${checked.length} выбрано`
    if (this.hasLabelTarget) {
      this.labelTarget.textContent = text
    } else if (this.hasButtonTarget) {
      this.buttonTarget.textContent = text
    }
  }
}

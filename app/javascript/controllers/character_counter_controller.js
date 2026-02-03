import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="character-counter"
export default class extends Controller {
  static targets = ["input", "counter"]

  connect() {
    console.log('connected character-counter');
    this.updateCounter()
    this.inputTarget.addEventListener("input", () => this.updateCounter())
  }

  updateCounter() {
    const len = this.inputTarget.value.length
    const max = this.inputTarget.maxLength || ""
    this.counterTarget.textContent = max ? `${len} / ${max}` : len
  }
}

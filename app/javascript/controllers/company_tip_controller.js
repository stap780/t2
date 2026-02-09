import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["rateField"]

  toggleRate(event) {
    const selectedTip = event.target.value
    const rateField = this.rateFieldTarget
    
    if (selectedTip === 'strah') {
      rateField.style.display = 'block'
    } else {
      rateField.style.display = 'none'
    }
  }
}

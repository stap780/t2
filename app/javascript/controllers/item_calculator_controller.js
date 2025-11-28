import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["quantity", "price", "sum"]
  static values = { itemId: String }

  connect() {
    this.calculate()
  }

  calculate() {
    const quantity = parseFloat(this.quantityTarget.value) || 0
    const price = parseFloat(this.priceTarget.value) || 0
    const sum = quantity * price
    
    this.sumTarget.value = sum.toFixed(2)
    
    // Обновляем totalsum через событие на window
    window.dispatchEvent(new CustomEvent("itemSumChanged", { 
      detail: { 
        itemId: this.itemIdValue, 
        sum: sum 
      } 
    }))
  }
}


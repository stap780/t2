import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["totalsum"]

  connect() {
    this.updateTotal()
  }

  updateTotal(event) {
    // Находим все поля сумм позиций
    const sumFields = document.querySelectorAll('[data-item-calculator-target="sum"]')
    let total = 0
    
    sumFields.forEach(field => {
      const value = parseFloat(field.value) || 0
      total += value
    })
    
    // Обновляем totalsum (div использует textContent, input использует value)
    if (this.hasTotalsumTarget) {
      const formattedTotal = total.toFixed(2)
      
      // Проверяем тип элемента
      if (this.totalsumTarget.tagName === 'INPUT' || this.totalsumTarget.tagName === 'TEXTAREA') {
        this.totalsumTarget.value = formattedTotal
      } else {
        // Для div и других элементов используем textContent
        this.totalsumTarget.textContent = formattedTotal
      }
    }
  }
}


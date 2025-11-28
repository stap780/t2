import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["companyCheckbox", "incaseCheckbox", "itemCheckbox"]

  connect() {
    // Controller initialized
  }

  toggleCompany(event) {
    const companyId = event.currentTarget.dataset.companyId
    const checked = event.currentTarget.checked
    
    // Находим все чекбоксы заявок и позиций для этой компании
    const incaseCheckboxes = this.element.querySelectorAll(
      `input[type="checkbox"][data-incase-checkbox][data-company-id="${companyId}"]`
    )
    const itemCheckboxes = this.element.querySelectorAll(
      `input[type="checkbox"][data-item-checkbox][data-company-id="${companyId}"]`
    )
    
    // Устанавливаем состояние всех чекбоксов заявок и позиций
    incaseCheckboxes.forEach(checkbox => {
      checkbox.checked = checked
    })
    itemCheckboxes.forEach(checkbox => {
      checkbox.checked = checked
    })
  }

  toggleIncase(event) {
    const incaseId = event.currentTarget.dataset.incaseId
    const checked = event.currentTarget.checked
    
    // Находим все чекбоксы позиций для этой заявки
    const itemCheckboxes = this.element.querySelectorAll(
      `input[type="checkbox"][data-item-checkbox][data-incase-id="${incaseId}"]`
    )
    
    // Устанавливаем состояние всех чекбоксов позиций
    itemCheckboxes.forEach(checkbox => {
      checkbox.checked = checked
    })
  }
}


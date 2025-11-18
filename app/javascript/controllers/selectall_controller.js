import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["checkbox", "parentCheckbox"]

  connect() {
    // Controller initialized
  }

  toggleParent() {
    // Чекбоксы находятся вне формы (внутри Turbo Frame), но связаны с формой через form: атрибут
    // Ищем все чекбоксы по всему документу, которые связаны с формой bulk_action_form
    // Используем универсальный селектор для всех чекбоксов с именем, заканчивающимся на _ids[]
    const allCheckboxes = document.querySelectorAll('input[type="checkbox"][name$="_ids[]"]')
    const filteredCheckboxes = Array.from(allCheckboxes).filter(cb => {
      const formId = cb.getAttribute('form')
      return (!formId || formId === 'bulk_action_form') && cb.name !== 'select_all'
    })
    
    const checkedCount = filteredCheckboxes.filter(cb => cb.checked).length
    const totalCount = filteredCheckboxes.length
    
    if (this.hasParentCheckboxTarget) {
      this.parentCheckboxTarget.checked = checkedCount === totalCount && totalCount > 0
      this.parentCheckboxTarget.indeterminate = checkedCount > 0 && checkedCount < totalCount
    }
  }

  toggleAll(event) {
    const checked = event.target.checked
    
    // Чекбоксы находятся вне формы (внутри Turbo Frame), но связаны с формой через form: атрибут
    // Ищем все чекбоксы по всему документу, которые связаны с формой bulk_action_form
    // Используем универсальный селектор для всех чекбоксов с именем, заканчивающимся на _ids[]
    const allCheckboxes = document.querySelectorAll('input[type="checkbox"][name$="_ids[]"]')
    
    const checkboxes = Array.from(allCheckboxes).filter(checkbox => {
      const formId = checkbox.getAttribute('form')
      return (!formId || formId === 'bulk_action_form') && checkbox.name !== 'select_all'
    })
    
    checkboxes.forEach(checkbox => {
      checkbox.checked = checked
    })
  }
}


import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["checkbox", "parentCheckbox"]
  static values = { group: String }

  connect() {
    // Инициализируем состояние родительского чекбокса при загрузке
    if (this.hasGroupValue) {
      this.updateParentState()
    }
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
    
    // Если указана группа, работаем только с чекбоксами этой группы
    if (this.hasGroupValue) {
      // Ищем все чекбоксы внутри этого элемента контроллера с нужным именем
      // Используем селектор для чекбоксов с именем, заканчивающимся на нужную группу
      const groupCheckboxes = Array.from(this.element.querySelectorAll('input[type="checkbox"]')).filter(checkbox => {
        return checkbox.name === `${this.groupValue}[]` && checkbox !== event.target
      })
      
      groupCheckboxes.forEach(checkbox => {
        checkbox.checked = checked
      })
      
      // Обновляем состояние родительского чекбокса
      this.updateParentState()
      return
    }
    
    // Старая логика для bulk_action_form
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

  updateParentState() {
    if (!this.hasGroupValue || !this.hasParentCheckboxTarget) return
    
    // Ищем все чекбоксы внутри этого элемента контроллера с нужным именем
    const groupCheckboxes = Array.from(this.element.querySelectorAll('input[type="checkbox"]')).filter(checkbox => {
      return checkbox.name === `${this.groupValue}[]` && checkbox !== this.parentCheckboxTarget
    })
    
    const checkedCount = groupCheckboxes.filter(cb => cb.checked).length
    const totalCount = groupCheckboxes.length
    
    if (totalCount > 0) {
      this.parentCheckboxTarget.checked = checkedCount === totalCount
      this.parentCheckboxTarget.indeterminate = checkedCount > 0 && checkedCount < totalCount
    }
  }

  toggleCheckbox() {
    // Вызывается при изменении отдельного чекбокса в группе
    if (this.hasGroupValue) {
      this.updateParentState()
    }
  }
}


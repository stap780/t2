import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="choose"
export default class extends Controller {
  static targets = ['itemResults', 'itemSelected']

  connect() {
  }

  changeBulkItemStatus(event){
    // Используем event.target, чтобы получить именно тот селект, который был изменен
    let selected = event.target
    let selectedValue = selected.value
    
    // Если значение пустое (prompt выбран), не делаем ничего
    if (!selectedValue || selectedValue === '') {
      return
    }
    
    // Определяем область действия: если селект находится внутри блока incase (локальный), 
    // то меняем только items в этом incase, иначе меняем все items
    let incaseBlock = selected.closest('.mb-6.border.border-gray-200')
    
    if (incaseBlock) {
      // Локальный селект - меняем только items в пределах того же incase блока
      incaseBlock.querySelectorAll('[data-choose-target="itemResults"]').forEach((element) => {
        element.value = selectedValue
        if (element.dataset.submitElement === 'true') {
          const form = element.closest('form')
          if (form) {
            form.requestSubmit()
          }
        }
      })
    } else {
      // Глобальный селект - меняем все items в пределах этого контроллера
      this.itemResultsTargets.forEach((element, index) => {
        element.value = selectedValue
        // Находим форму и отправляем её только если элемент имеет data-submit-element='true'
        if (element.dataset.submitElement === 'true') {
          const form = element.closest('form')
          if (form) {
            form.requestSubmit()
          }
        }
      })
    }
  }
}

import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="choose"
export default class extends Controller {
  static targets = ['itemResults','itemSelected']
  
  connect() {
  }

  changeBulkItemStatus(event){
    let selected = this.itemSelectedTarget
    this.itemResultsTargets.forEach((element, index) => {
      element.value = selected.value
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

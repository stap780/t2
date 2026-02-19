import { Controller } from "@hotwired/stimulus"

// Для incases/items: массовая подстановка статуса в поля формы (без отправки)
export default class extends Controller {
  static targets = ['itemResults']

  changeBulkItemStatus(event) {
    const selectedValue = event.target.value
    if (!selectedValue) return

    this.element.querySelectorAll('[data-choose-target="itemResults"]').forEach((el) => {
      el.value = selectedValue
    })
  }
}

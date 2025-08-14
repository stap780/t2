import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="export-form"
export default class extends Controller {
  static targets = ["fieldSelection", "templateSection"]
  static values = { }

  connect() {
    this.toggleSections()
  }

  formatChanged() {
    this.toggleSections()
  }

  selectAllFields() {
    const checkboxes = this.fieldSelectionTarget.querySelectorAll('input[type="checkbox"]')
    checkboxes.forEach(checkbox => {
      checkbox.checked = true
    })
  }

  deselectAllFields() {
    const checkboxes = this.fieldSelectionTarget.querySelectorAll('input[type="checkbox"]')
    checkboxes.forEach(checkbox => {
      checkbox.checked = false
    })
  }

  toggleSections() {
    const selectedFormat = this.getSelectedFormat()
    
    if (selectedFormat === 'csv' || selectedFormat === 'xlsx') {
      // Show field selection for CSV and XLSX
      this.fieldSelectionTarget.style.display = 'block'
      this.templateSectionTarget.style.display = 'none'
    } else if (selectedFormat === 'xml') {
      // Show template section for XML
      this.fieldSelectionTarget.style.display = 'none'
      this.templateSectionTarget.style.display = 'block'
    } else {
      // No format selected - hide both
      this.fieldSelectionTarget.style.display = 'none'
      this.templateSectionTarget.style.display = 'none'
    }
  }

  getSelectedFormat() {
    const formatRadios = this.element.querySelectorAll('input[name="export[format]"]')
    
    for (const radio of formatRadios) {
      if (radio.checked) {
        return radio.value
      }
    }
    
    return ''
  }
}

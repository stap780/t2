import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "filename"]
  
  connect() {
    this.element.addEventListener("dragover", this.handleDragOver.bind(this))
    this.element.addEventListener("dragleave", this.handleDragLeave.bind(this))
    this.element.addEventListener("drop", this.handleDrop.bind(this))
  }
  
  handleDragOver(event) {
    event.preventDefault()
    event.stopPropagation()
    this.highlight()
  }
  
  handleDragLeave(event) {
    event.preventDefault()
    event.stopPropagation()
    this.unhighlight()
  }
  
  handleDrop(event) {
    event.preventDefault()
    event.stopPropagation()
    this.unhighlight()
    
    const files = event.dataTransfer.files
    if (files.length > 0) {
      this.inputTarget.files = files
      this.updateFilename(files[0].name)
    }
  }
  
  handleFileSelect(event) {
    const files = event.target.files
    if (files.length > 0) {
      this.updateFilename(files[0].name)
    }
  }
  
  highlight() {
    this.element.classList.add("border-violet-500", "bg-violet-50")
  }
  
  unhighlight() {
    this.element.classList.remove("border-violet-500", "bg-violet-50")
  }
  
  updateFilename(filename) {
    if (this.hasFilenameTarget) {
      this.filenameTarget.textContent = filename
    }
  }
}


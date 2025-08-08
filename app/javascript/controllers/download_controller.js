import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button"]

  download(event) {
    const button = event.currentTarget
    const originalText = button.innerHTML
    
    // Show loading state
    button.innerHTML = `
      <svg class="animate-spin h-4 w-4 mr-1" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
      </svg>
      Downloading...
    `
    button.classList.add("opacity-75", "cursor-not-allowed")
    button.disabled = true

    // Reset after download starts (give it time to initiate)
    setTimeout(() => {
      button.innerHTML = originalText
      button.classList.remove("opacity-75", "cursor-not-allowed")
      button.disabled = false
    }, 2000)
  }
}

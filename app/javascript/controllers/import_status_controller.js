import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["status", "progress"]

  connect() {
    console.log("Import status controller connected")
  }

  updateProgress() {
    // Add visual feedback for status changes
    const statusElement = this.statusTarget
    if (statusElement) {
      statusElement.classList.add("animate-pulse")
      setTimeout(() => {
        statusElement.classList.remove("animate-pulse")
      }, 2000)
    }
  }

  // Handle status changes from Turbo Stream updates
  statusChanged() {
    console.log("Import status changed - refreshing display")
    this.updateProgress()
  }
}

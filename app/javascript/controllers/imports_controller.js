// imports_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["status", "progress"]
  static values = { url: String, refreshInterval: Number }
  
  connect() {
    // Initialize auto-refresh for processing imports
    if (this.hasRefreshIntervalValue && this.refreshIntervalValue > 0) {
      this.startAutoRefresh()
    }
  }
  
  disconnect() {
    this.stopAutoRefresh()
  }
  
  startAutoRefresh() {
    this.refreshTimer = setInterval(() => {
      this.refreshStatus()
    }, this.refreshIntervalValue * 1000)
  }
  
  stopAutoRefresh() {
    if (this.refreshTimer) {
      clearInterval(this.refreshTimer)
      this.refreshTimer = null
    }
  }
  
  refreshStatus() {
    if (this.hasUrlValue) {
      fetch(this.urlValue, {
        headers: {
          'Accept': 'text/vnd.turbo-stream.html'
        }
      })
      .then(response => response.text())
      .then(html => {
        Turbo.renderStreamMessage(html)
      })
      .catch(error => {
        console.error('Error refreshing import status:', error)
      })
    }
  }
  
  createImport(event) {
    // Handle create import button click
    event.preventDefault()
    
    // Show loading state
    const button = event.target
    const originalText = button.textContent
    button.textContent = 'Creating...'
    button.disabled = true
    
    // Reset button after form submission
    setTimeout(() => {
      button.textContent = originalText
      button.disabled = false
    }, 2000)
  }
}

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "panel"]

  switch(event) {
    const tabName = event.currentTarget.dataset.tabName
    
    // Hide all panels
    this.panelTargets.forEach(panel => {
      if (panel.dataset.tabName === tabName) {
        panel.classList.remove("hidden")
      } else {
        panel.classList.add("hidden")
      }
    })
    
    // Update active tab
    this.tabTargets.forEach(tab => {
      if (tab.dataset.tabName === tabName) {
        tab.classList.add("border-violet-600", "text-violet-600")
        tab.classList.remove("text-gray-500", "border-transparent")
      } else {
        tab.classList.remove("border-violet-600", "text-violet-600")
        tab.classList.add("text-gray-500", "border-transparent")
      }
    })
  }
}


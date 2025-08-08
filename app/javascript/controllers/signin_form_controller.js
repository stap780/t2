import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["email", "password", "submit", "toggleButton", "eyeIcon", "eyeOffIcon"]
  
  connect() {
    // Add loading state management
    this.isLoading = false
    
    // Add form validation
    this.validateForm()
  }

  togglePassword() {
    const passwordField = this.passwordTarget
    const eyeIcon = this.eyeIconTarget
    const eyeOffIcon = this.eyeOffIconTarget
    
    if (passwordField.type === "password") {
      passwordField.type = "text"
      eyeIcon.classList.add("hidden")
      eyeOffIcon.classList.remove("hidden")
    } else {
      passwordField.type = "password"
      eyeIcon.classList.remove("hidden")
      eyeOffIcon.classList.add("hidden")
    }
  }

  validateForm() {
    const email = this.emailTarget
    const password = this.passwordTarget
    const submitButton = this.submitTarget
    
    const checkValidity = () => {
      const isValid = email.value.trim() !== "" && 
                     password.value.trim() !== "" && 
                     this.isValidEmail(email.value)
      
      if (isValid) {
        submitButton.classList.remove("opacity-50", "cursor-not-allowed")
        submitButton.disabled = false
      } else {
        submitButton.classList.add("opacity-50", "cursor-not-allowed")
        submitButton.disabled = true
      }
    }
    
    email.addEventListener("input", checkValidity)
    password.addEventListener("input", checkValidity)
    
    // Initial check
    checkValidity()
  }

  isValidEmail(email) {
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
    return emailRegex.test(email)
  }

  submit(event) {
    if (this.isLoading) {
      event.preventDefault()
      return
    }
    
    this.isLoading = true
    const submitButton = this.submitTarget
    const originalText = submitButton.textContent
    
    // Add loading state
    submitButton.innerHTML = `
      <svg class="animate-spin -ml-1 mr-3 h-5 w-5 text-white inline" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
      </svg>
      Signing in...
    `
    submitButton.disabled = true
    
    // Reset after potential form error
    setTimeout(() => {
      this.isLoading = false
      submitButton.textContent = originalText
      submitButton.disabled = false
    }, 5000)
  }
}

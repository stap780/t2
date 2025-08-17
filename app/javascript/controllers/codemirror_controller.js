import { Controller } from "@hotwired/stimulus"

// Uses CodeMirror v5 global (loaded in layout)
export default class extends Controller {
  static values = { mode: { type: String, default: "xml" } }

  connect() {
    this.textarea = this.element
    if (!window.CodeMirror || !this.textarea) return

    // Wrap textarea for styling
    this.wrapper = document.createElement("div")
    this.wrapper.className = "border-2 border-gray-200 rounded-lg overflow-hidden"
    this.textarea.parentNode.insertBefore(this.wrapper, this.textarea.nextSibling)

    // Initialize CodeMirror from textarea
    this.editor = window.CodeMirror.fromTextArea(this.textarea, {
      mode: this.modeValue === "xml" ? "xml" : this.modeValue,
      lineWrapping: true,
      lineNumbers: true,
      styleActiveLine: true,
      matchBrackets: true,
      theme: "default"
    })

    // Move the editor DOM into our wrapper for consistent styling
    const cmEl = this.editor.getWrapperElement()
    if (cmEl && cmEl.parentNode) {
      this.wrapper.appendChild(cmEl)
    }

    // Size similar to ~16 rows
    this.editor.setSize("100%", "22rem")

    // Mirror changes back to textarea so form submits the value
    this.editor.on("change", () => {
      this.editor.save() // writes back into underlying textarea
      this.textarea.dispatchEvent(new Event("input", { bubbles: true }))
      this.textarea.dispatchEvent(new Event("change", { bubbles: true }))
    })
  }

  disconnect() {
    if (this.editor) {
      // Detach the CodeMirror instance and show original textarea
      const wrapper = this.editor.getWrapperElement()
      if (wrapper && wrapper.parentNode) wrapper.parentNode.removeChild(wrapper)
      this.editor = null
    }
    if (this.wrapper) this.wrapper.remove()
    if (this.textarea) this.textarea.style.display = ""
  }
}

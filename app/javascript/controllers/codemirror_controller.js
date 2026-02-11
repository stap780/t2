import { Controller } from "@hotwired/stimulus"
import { basicSetup, EditorView } from "codemirror"
import { StreamLanguage } from "@codemirror/language"
import { xml } from "@codemirror/legacy-modes/mode/xml"

// Uses CodeMirror v5 global (loaded in layout)
export default class extends Controller {
  static targets = [ "editor", "input" ]
  static values = { doc: String }

  connect() {
    this.editor = new EditorView({
      doc: this.docValue,
      extensions: [
        StreamLanguage.define(xml),
        basicSetup,
        EditorView.updateListener.of((view) => {
          if (view.docChanged) {
            this.sync()
          }
        }),
      ],
      parent: this.element,
    })

    // Set minimum height of 200px
    this.editor.dom.style.minHeight = "200px"
  }

  sync() {
    this.inputTarget.value = this.editor.state.doc.toString()
  }

  disconnect() {
    this.editor.destroy()
  }

}

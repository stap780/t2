import { Controller } from "@hotwired/stimulus"

// Подсказки вариантов: debounce + GET с ответом turbo_stream (сервер ренерит partial)
export default class extends Controller {
  static targets = ["query"]
  static values = { url: String, forItemId: String }

  connect() {
    this._timeout = null
  }

  disconnect() {
    clearTimeout(this._timeout)
  }

  search() {
    clearTimeout(this._timeout)
    this._timeout = setTimeout(() => this._fetchSuggestions(), 300)
  }

  _fetchSuggestions() {
    const q = this.queryTarget.value.trim()
    const url = new URL(this.urlValue, window.location.origin)
    url.searchParams.set("title", q)
    url.searchParams.set("for_item_id", this.forItemIdValue)

    fetch(url.toString(), {
      headers: { Accept: "text/vnd.turbo-stream.html" }
    })
      .then((response) => response.text())
      .then((html) => {
        Turbo.renderStreamMessage(html)
      })
      .catch(() => {
        /* ignore */
      })
  }
}

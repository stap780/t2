import Lightbox from "@stimulus-components/lightbox"

export default class extends Lightbox {
  connect() {
    super.connect()
    this.boundBeforeStream = this.beforeStreamRender.bind(this)
    document.addEventListener("turbo:before-stream-render", this.boundBeforeStream)
  }

  disconnect() {
    document.removeEventListener("turbo:before-stream-render", this.boundBeforeStream)
    super.disconnect()
  }

  beforeStreamRender(event) {
    const originalRender = event.detail.render
    if (typeof originalRender !== "function") return

    event.detail.render = async (streamElement) => {
      await originalRender(streamElement)
      if (!(streamElement instanceof Element)) return

      const target = streamElement.getAttribute("target")
      if (target !== "images") return

      if (this.lightGallery && typeof this.lightGallery.refresh === "function") {
        this.lightGallery.refresh()
      }
    }
  }

  get defaultOptions() {
    return {
      selector: "a.lg-image-link"
    }
  }
}

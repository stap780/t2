import Lightbox from "@stimulus-components/lightbox"

// Connects to data-controller="lightbox"
export default class extends Lightbox {
  connect() {
    super.connect()
  }

  get defaultOptions() {
    return {
      selector: "a.lg-image-link"
    }
  }
}

import { Controller } from "@hotwired/stimulus"
import { DirectUpload } from "@rails/activestorage";
import { post } from "@rails/request.js"

// Connects to data-controller="image"
export default class extends Controller {
  static targets = ["filesInput","fileItem"];
  static values = { productId: Number };

  connect() {
    console.log('[Image] Controller connected', {
      hasFilesInputTarget: this.hasFilesInputTarget,
      filesInputTarget: this.hasFilesInputTarget ? this.filesInputTarget : null,
      productId: this.productIdValue
    });
  }

  triggerFileInput(event) {
    // Активируем input при клике на кнопку
    // Это синхронный вызов в обработчике пользовательского события, поэтому Chrome разрешит
    if (this.hasFilesInputTarget) {
      event.preventDefault();
      this.filesInputTarget.click();
    }
  }

  // Bind to normal file selection
  uploadFile(event) {
    const filesInput = this.filesInputTarget;
    const url = filesInput.dataset.directUploadUrl;
    Array.from(filesInput.files).forEach(file => {
      this.createUploadController(file, url).start();
    })
    filesInput.value = "";
  }

  removeFile(event) {
    // not use
  }

  createUploadController(file, url) {
    return new DirectUploadController(file, url, this);
  }
}

class DirectUploadController {
  constructor(file, url, imageController) {
    this.directUpload = this.createDirectUpload(file, url, this);
    this.file = file;
    this.imageController = imageController;
  }

  start() {
    this.directUpload.create((error, blob) => {
      if (error) {
        alert(error);
      } else {
        this.uploadToActiveStorage(blob);
      }
    })
  }

  directUploadWillStoreFileWithXHR(request) {
    request.upload.addEventListener("progress",
      event => this.directUploadDidProgress(event))
  }

  directUploadDidProgress(event) {
    // Use event.loaded and event.total to update the progress bar
  }

  createDirectUpload(file, url, controller) {
    return new DirectUpload(file, url, controller);
  }

  async uploadToActiveStorage(blob) {
    // Получаем product_id из value контроллера image
    const productId = this.imageController.productIdValue;
    
    const body = { blob_signed_id: blob.signed_id };
    if (productId && productId > 0) {
      body.product_id = productId;
    }
    
    const response = await post("/images/upload", {
      body: JSON.stringify(body),
      responseKind: "turbo-stream",
    })
    
    return response.status === 204
  }
}

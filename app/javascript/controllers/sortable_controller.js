import { Controller } from "@hotwired/stimulus"
import { patch } from "@rails/request.js"
import Sortable from "sortablejs"

export default class extends Controller {
  static targets = [ 'position', 'hposition' ]
  
  connect() {
    this.sortable = new Sortable(this.element, {
      handle: '.js-sort-handle',
      filter: '#images-placeholder',
      onEnd: async (e) => {
        try {
          this.disable()
          const url = e.item.dataset.sortUrl;
          const resp = await patch(url, {
            body: JSON.stringify({
              "sort_item_id": e.item.dataset.sortItemId,
              "new_position": e.newIndex + 1,
              "old_position": e.oldIndex + 1,
            })
          })

          if(!resp.ok) {
            this.updatePositions();
            throw new Error(`Cannot sort on server: ${resp.statusCode}`)
          }

          this.updatePositions()
          this.dispatch('move', { detail: { content: 'Item sort' } })
        } catch(e) {
          console.error(e)
        } finally {
          this.enable()
        }
      }
    })
  }

  disable() {
    this.sortable.option('disabled', true)
    this.sortable.el.classList.add('opacity-50')
  }

  enable() {
    this.sortable.option('disabled', false)
    this.sortable.el.classList.remove('opacity-50')
  }

  updatePositions() {
    this.positionTargets.forEach((position, index) => {
      position.innerText = index + 1
    })
    this.hpositionTargets.forEach((position, index) => {
      position.value = index + 1
    })
  }
}

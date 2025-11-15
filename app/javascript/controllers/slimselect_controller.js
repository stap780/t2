import { Controller } from "@hotwired/stimulus"
import { get, post } from "@rails/request.js"
import SlimSelect from "slim-select"

export default class extends Controller {
  connect() {
    this.initializeSlimSelect()
  }

  disconnect() {
    if (this.slimselect) {
      this.slimselect.destroy()
      this.slimselect = null
    }
  }

  initializeSlimSelect() {
    // Уничтожаем предыдущий экземпляр, если он существует
    if (this.slimselect) {
      this.slimselect.destroy()
      this.slimselect = null
    }

    const searchUrl = this.element.dataset.searchUrl
    const nestedUrl = this.element.dataset.nestedUrl
    
    // nestedUrl нужен только для property select, для characteristic select его нет - это нормально
    // Диагностика только если это property select (имеет nested_url) но он отсутствует
    if (this.element.name && this.element.name.includes('property_id') && !nestedUrl) {
      console.warn('[SlimSelect] nestedUrl not found for property select', {
        element: this.element,
        dataset: this.element.dataset,
        browser: navigator.userAgent
      })
    }
    
    this.slimselect = new SlimSelect({
      select: this.element,
      settings: {},
      events: {
        search: (search, currentData) => {
          return new Promise((resolve, reject) => {
            if (search.length < 2) {
              return reject('Search must be at least 2 characters')
            }
            if (searchUrl != undefined) {
              const propertyId = this.element.dataset.propertyId
              const body = propertyId ? 
                JSON.stringify({ title: search, property_id: propertyId }) :
                JSON.stringify({ title: search })
              
              // Используем fetch напрямую для получения JSON
              fetch(searchUrl, {
                method: 'POST',
                headers: {
                  "Content-Type": "application/json",
                  "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content,
                  "Accept": "application/json"
                },
                body: body
              })
                .then((response) => {
                  if (response.ok) {
                    return response.json()
                  } else {
                    throw new Error(`HTTP error! status: ${response.status}`)
                  }
                })
                .then((data) => {
                  const options = data.map((d) => {
                    return {
                      text: `${d.title}`,
                      value: `${d.id}`,
                    }
                  })
                  resolve(options)
                })
                .catch((error) => {
                  console.error('Search error:', error)
                  reject(error)
                })
            } else {
              reject('No search URL provided')
            }
          })
        },
        afterChange: (newVal) => {
          if (nestedUrl != undefined && newVal && newVal.length > 0) {
            // Получаем turbo_frame_id из data-атрибута turbo_frame
            const turboFrameId = this.element.dataset.turboFrame
            
            console.log('[SlimSelect] afterChange triggered', {
              nestedUrl,
              turboFrameId,
              propertyId: newVal[0].value,
              productId: this.element.dataset.productId,
              browser: navigator.userAgent
            })
            
            if (turboFrameId) {
              // Создаем URL объект для правильной обработки параметров
              const urlObj = new URL(nestedUrl, window.location.origin)
              
              urlObj.searchParams.append("property_id", newVal[0].value)
              urlObj.searchParams.append("turbo_frame_id", turboFrameId)
              
              const productId = this.element.dataset.productId
              
              if (productId) {
                urlObj.searchParams.append("product_id", productId)
              }
              
              const url = urlObj.pathname + urlObj.search
              console.log('[SlimSelect] Sending request to:', url)
              
              get(url, {
                responseKind: "turbo-stream"
              }).then((response) => {
                console.log('[SlimSelect] Response received', {
                  ok: response.ok,
                  status: response.status,
                  statusText: response.statusText
                })
                if (!response.ok) {
                  console.error('Failed to update characteristics:', response.status, response.statusText)
                }
              }).catch((error) => {
                console.error('[SlimSelect] Error updating characteristics:', error, {
                  browser: navigator.userAgent
                })
              })
            } else {
              console.warn('[SlimSelect] turbo_frame_id not found in data attributes', {
                dataset: this.element.dataset,
                browser: navigator.userAgent
              })
            }
          } else {
            console.warn('[SlimSelect] afterChange skipped', {
              nestedUrl,
              hasValue: newVal && newVal.length > 0,
              browser: navigator.userAgent
            })
          }
        }
      }
    })
  }

}


# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin "trix"
pin "@rails/actiontext", to: "actiontext.esm.js"
pin "@rails/activestorage", to: "activestorage.esm.js"
pin "@rails/request.js", to: "https://cdn.jsdelivr.net/npm/@rails/request.js@0.0.12/+esm"
pin "sortablejs", to: "https://cdn.jsdelivr.net/npm/sortablejs@latest/+esm"
pin "@fancyapps/ui", to: "https://cdn.jsdelivr.net/npm/@fancyapps/ui@5.0/dist/fancybox/fancybox.esm.js"
pin "slim-select", to: "https://cdn.jsdelivr.net/npm/slim-select@2.8.2/dist/slimselect.es.min.js"
pin "flatpickr" # @4.6.13
pin "stimulus-flatpickr" # @3.0.0
pin_all_from "app/javascript/controllers", under: "controllers"

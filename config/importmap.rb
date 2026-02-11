# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "@hotwired--stimulus.js" # @3.2.2
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
pin "@stimulus-components/character-counter", to: "@stimulus-components--character-counter.js" # @5.1.0
pin_all_from "app/javascript/controllers", under: "controllers"
pin "codemirror" # @6.0.2
pin "@codemirror/autocomplete", to: "@codemirror--autocomplete.js" # @6.20.0
pin "@codemirror/commands", to: "@codemirror--commands.js" # @6.10.2
pin "@codemirror/language", to: "@codemirror--language.js" # @6.12.1
pin "@codemirror/lint", to: "@codemirror--lint.js" # @6.9.3
pin "@codemirror/search", to: "@codemirror--search.js" # @6.6.0
pin "@codemirror/state", to: "@codemirror--state.js" # @6.5.4
pin "@codemirror/view", to: "@codemirror--view.js" # @6.39.13
pin "@lezer/common", to: "@lezer--common.js" # @1.5.1
pin "@lezer/highlight", to: "@lezer--highlight.js" # @1.2.3
pin "@marijn/find-cluster-break", to: "@marijn--find-cluster-break.js" # @1.0.2
pin "crelt" # @1.0.6
pin "style-mod" # @4.1.3
pin "w3c-keyname" # @2.2.8
pin "@codemirror/legacy-modes/mode/xml", to: "@codemirror--legacy-modes--mode--xml.js" # @6.5.2

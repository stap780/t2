# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "@hotwired--stimulus.js" # @3.2.2
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin "trix"
pin "@rails/actiontext", to: "actiontext.esm.js"
pin "@rails/activestorage", to: "activestorage.esm.js"
pin "@rails/request.js", to: "@rails--request.js.js" # @0.0.13
pin "sortablejs" # @1.15.7
pin "slim-select" # @3.4.0
pin "flatpickr" # @4.6.13
pin "stimulus-flatpickr" # @3.0.0
pin "@stimulus-components/character-counter", to: "@stimulus-components--character-counter.js" # @5.1.0
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
pin "@stimulus-components/lightbox", to: "@stimulus-components--lightbox.js" # @4.0.0
pin "lightgallery" # @2.9.0
pin "@stimulus-components/chartjs", to: "@stimulus-components--chartjs.js" # @6.0.1
pin "@kurkle/color", to: "@kurkle--color.js" # @0.3.4
pin "chart.js", to: "https://esm.sh/chart.js@4.5.1", preload: true
pin_all_from "app/javascript/controllers", under: "controllers"

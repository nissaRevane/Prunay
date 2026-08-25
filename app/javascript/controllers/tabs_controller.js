import { Controller } from "@hotwired/stimulus"

// Deux vues d'une même simulation : ses paramètres et sa projection. Les deux panneaux sont
// rendus par le serveur — l'onglet ne fait que choisir lequel se montre, sans aller-retour.
export default class extends Controller {
  static targets = ["tab", "panel"]
  static values = { index: Number }

  connect() {
    this.showPanel()
  }

  select(event) {
    this.indexValue = this.tabTargets.indexOf(event.currentTarget)
  }

  indexValueChanged() {
    this.showPanel()
  }

  showPanel() {
    this.tabTargets.forEach((tab, index) => {
      const current = index === this.indexValue

      tab.classList.toggle("is-active", current)
      tab.setAttribute("aria-selected", current)
      tab.setAttribute("tabindex", current ? "0" : "-1")
    })

    this.panelTargets.forEach((panel, index) => {
      panel.hidden = index !== this.indexValue
    })
  }
}

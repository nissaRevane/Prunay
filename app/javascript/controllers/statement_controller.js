import { Controller } from "@hotwired/stimulus"

// La fiche d'une année se lit sous deux angles : ce que l'année a produit, et ce qu'une revente
// laisserait le jour de son anniversaire. Les deux sont rendus par le serveur — l'onglet ne fait
// que choisir lequel se montre, titre compris.
export default class extends Controller {
  static targets = ["tab", "view"]
  static values = { view: String }

  select(event) {
    this.viewValue = event.params.name
  }

  // Refermée, la fiche revient à son compte de résultat : c'est par là qu'on la rouvre.
  reset() {
    this.viewValue = this.tabTargets[0].dataset.view
  }

  viewValueChanged() {
    this.showView()
  }

  showView() {
    this.tabTargets.forEach((tab) => {
      const current = tab.dataset.view === this.viewValue

      tab.classList.toggle("is-active", current)
      tab.setAttribute("aria-selected", current)
      tab.setAttribute("tabindex", current ? "0" : "-1")
    })

    this.viewTargets.forEach((view) => {
      view.hidden = view.dataset.view !== this.viewValue
    })
  }
}

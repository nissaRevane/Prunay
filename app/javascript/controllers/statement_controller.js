import { Controller } from "@hotwired/stimulus"

// La fiche d'une année se lit sous deux angles : ce que l'année a produit, et ce qu'une revente
// laisserait le jour de son anniversaire. Tout est rendu par le serveur — l'onglet ne fait que
// choisir lequel se montre, titre compris, et le détail que déplier le calcul de chaque ligne.
export default class extends Controller {
  static targets = ["tab", "view", "detail", "toggle"]
  static values = { view: String, detail: Boolean }

  select(event) {
    this.viewValue = event.params.name
  }

  // Le calcul de chaque ligne se demande, et vaut pour les deux angles à la fois.
  toggleDetail() {
    this.detailValue = !this.detailValue
  }

  // Refermée, la fiche revient à son compte de résultat, résumé : c'est par là qu'on la rouvre.
  reset() {
    this.viewValue = this.tabTargets[0].dataset.view
    this.detailValue = false
  }

  detailValueChanged() {
    this.detailTargets.forEach((detail) => {
      detail.hidden = !this.detailValue
    })

    this.toggleTarget.classList.toggle("is-active", this.detailValue)
    this.toggleTarget.setAttribute("aria-pressed", this.detailValue)
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

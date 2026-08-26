import { Controller } from "@hotwired/stimulus"

// La copropriété se déduit du type de bien : un appartement en est presque toujours, une
// maison presque jamais. Le serveur propose déjà la bonne case au premier affichage ; ce
// contrôleur ne fait que la suivre quand le type change sous les yeux de l'utilisateur.
//
// C'est une proposition et non une règle : la case reste libre, et la décocher suffit à la
// contredire. Choisir un autre type est en revanche une nouvelle réponse, à laquelle la
// proposition répond de nouveau.
export default class extends Controller {
  static targets = ["propertyType", "checkbox"]
  static values = { type: String }

  suggest() {
    const suggested = this.propertyTypeTarget.value === this.typeValue
    if (this.checkboxTarget.checked === suggested) return

    this.checkboxTarget.checked = suggested

    // Le formulaire de modification écoute cette case pour montrer ou masquer les charges de
    // copropriété ; cochée par un script, elle n'émet rien d'elle-même.
    this.checkboxTarget.dispatchEvent(new Event("change", { bubbles: true }))
  }
}

import { Controller } from "@hotwired/stimulus"

// Les charges qu'une condition gouverne apparaissent avec elle : on ne demande pas de charges
// de copropriété pour une maison. Le serveur rend déjà l'état juste ; ce contrôleur ne sert
// qu'au formulaire de modification, où la copropriété se répond au-dessus des charges et peut
// changer sans recharger la page.
//
// Un champ écarté est masqué et désactivé : requis et invisible, il bloquerait l'envoi du
// formulaire, et le modèle remet à zéro le montant qu'il ne reçoit pas.
export default class extends Controller {
  static targets = ["condominium"]

  refresh() {
    this.#apply("condominium", this.condominiumTarget.checked)
  }

  #apply(condition, applicable) {
    this.element.querySelectorAll(`[data-charges-condition="${condition}"]`).forEach((field) => {
      field.hidden = !applicable
      field.querySelectorAll("input").forEach((input) => { input.disabled = !applicable })
    })
  }
}

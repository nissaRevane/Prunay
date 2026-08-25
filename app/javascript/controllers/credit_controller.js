import { Controller } from "@hotwired/stimulus"

// Le financement, là où il se déclare : la case « achat à crédit », et ce qu'elle fait
// apparaître — l'apport sur la page de l'achat, le taux et la durée sur le formulaire de
// modification. Un champ écarté est masqué ET désactivé : requis et invisible, il bloquerait
// l'envoi du formulaire, et le modèle remet à zéro ce qu'il ne reçoit pas.
//
// L'apport se propose à un dixième du coût du projet — prix, frais de notaire et travaux. Ce
// coût se tape sur la page même, et seul le navigateur peut donc suivre la proposition à la
// frappe ; dès que l'utilisateur corrige le montant, la proposition se tait et ne revient
// plus. Le taux et la part fixe des frais de notaire viennent du modèle, comme pour le
// contrôleur `notary-fees` : la formule ne doit pas se réécrire ici.
export default class extends Controller {
  static targets = ["toggle", "field", "price", "works", "downPayment"]
  static values = { rate: Number, base: Number, share: Number, rounding: Number }

  connect() {
    // Un apport déjà saisi qui ne coïncide pas avec la proposition est une correction :
    // rouvrir le formulaire ne doit pas l'effacer.
    this.manual = this.downPaymentTarget.value !== "" &&
                  Number(this.downPaymentTarget.value) !== this.#suggestion()

    this.refresh()
  }

  refresh() {
    const applicable = this.toggleTarget.checked

    this.fieldTargets.forEach((field) => {
      field.hidden = !applicable
      field.querySelectorAll("input").forEach((input) => { input.disabled = !applicable })
    })

    this.suggest()
  }

  markManual() {
    this.manual = true
  }

  suggest() {
    if (this.manual) return

    this.downPaymentTarget.value = this.#suggestion()
  }

  #suggestion() {
    const price = parseFloat(this.priceTarget.value)
    if (!(price > 0)) return 0

    const works = parseFloat(this.worksTarget.value) || 0
    const total = price + price * this.rateValue + this.baseValue + works

    return Math.round(total * this.shareValue / this.roundingValue) * this.roundingValue
  }
}

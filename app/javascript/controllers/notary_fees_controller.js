import { Controller } from "@hotwired/stimulus"

const EUROS = new Intl.NumberFormat("fr-FR", { style: "currency", currency: "EUR" })

// Les frais de notaire se déduisent du prix. Le serveur les recalcule à l'affichage, mais
// tant que l'utilisateur tape son prix, seule la page peut le lui montrer : ce contrôleur
// les recalcule à la frappe, avec le taux et la part fixe que le modèle lui a passés.
export default class extends Controller {
  static targets = ["price", "amount"]
  static values = { rate: Number, base: Number }

  connect() {
    this.refresh()
  }

  refresh() {
    const price = parseFloat(this.priceTarget.value)
    const fees = price > 0 ? price * this.rateValue + this.baseValue : 0

    this.amountTarget.textContent = EUROS.format(fees)
  }
}

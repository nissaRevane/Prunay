import { Controller } from "@hotwired/stimulus"

const EUROS = new Intl.NumberFormat("fr-FR", { style: "currency", currency: "EUR" })

const MONTHS_PER_YEAR = 12

// La mensualité d'un prêt à annuités constantes : M = C × i / (1 − (1 + i)^−n). Le serveur la
// calcule aussi, mais tant que l'utilisateur essaie des taux et des durées, seule la page peut
// la lui montrer — c'est ce qu'il vient chercher sur cette page. Le capital emprunté, lui, ne
// bouge plus : il a été fixé à la page précédente, et le modèle le passe en valeur.
export default class extends Controller {
  static targets = ["rate", "duration", "payment", "interest"]
  static values = { capital: Number }

  connect() {
    this.refresh()
  }

  refresh() {
    const months = Math.round(parseFloat(this.durationTarget.value) * MONTHS_PER_YEAR)
    const rate = parseFloat(this.rateTarget.value) / 100 / MONTHS_PER_YEAR
    const capital = this.capitalValue

    if (!(capital > 0) || !(months > 0) || !(rate >= 0)) return

    const exact = rate === 0 ? capital / months : capital * rate / (1 - Math.pow(1 + rate, -months))
    // Au centime, comme la banque l'énonce et comme le modèle l'arrondit.
    const payment = Math.round(exact * 100) / 100

    this.paymentTarget.textContent = EUROS.format(payment)
    this.interestTarget.textContent = EUROS.format(payment * months - capital)
  }
}

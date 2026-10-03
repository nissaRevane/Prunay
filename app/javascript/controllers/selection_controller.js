import { Controller } from "@hotwired/stimulus"

// Le mode sélection de la liste : une carte se coche d'un clic, la barre compte et supprime.
export default class extends Controller {
  static targets = ["item", "all", "count", "submit"]
  static values = { one: String, other: String }

  start() {
    this.element.classList.add("is-selecting")
  }

  stop() {
    this.element.classList.remove("is-selecting")
    this.itemTargets.forEach((item) => (item.checked = false))
    this.refresh()
  }

  toggleAll() {
    this.itemTargets.forEach((item) => (item.checked = this.allTarget.checked))
    this.refresh()
  }

  // Le cadre de la liste se recharge à chaque filtre ou page : on recompte à l'arrivée.
  itemTargetConnected() {
    this.refresh()
  }

  submitTargetConnected() {
    this.refresh()
  }

  refresh() {
    if (!this.hasSubmitTarget) return

    const total = this.itemTargets.length
    const checked = this.itemTargets.filter((item) => item.checked).length
    const label = checked > 1 ? this.otherValue : this.oneValue

    this.countTarget.textContent = label.replace("%{count}", checked)
    this.submitTarget.disabled = checked === 0
    this.allTarget.checked = total > 0 && checked === total
    this.allTarget.indeterminate = checked > 0 && checked < total
  }
}

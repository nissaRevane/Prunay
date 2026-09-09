import { Controller } from "@hotwired/stimulus"

// Sur mobile le menu se replie derrière le burger : les liens, le compte et la déconnexion
// vivent dans le même panneau, que le CSS déplie et que ce contrôleur ouvre.
export default class extends Controller {
  static targets = ["burger", "menu"]
  static values = { open: Boolean }

  toggle() {
    this.openValue = !this.openValue
  }

  close() {
    this.openValue = false
  }

  // Un clic ailleurs ou la touche d'échappement referment le panneau.
  closeOnOutsideClick(event) {
    if (!this.element.contains(event.target)) this.close()
  }

  closeOnEscape() {
    this.close()
  }

  openValueChanged() {
    if (!this.hasBurgerTarget) return

    this.element.classList.toggle("is-open", this.openValue)
    this.burgerTarget.setAttribute("aria-expanded", this.openValue)
  }
}

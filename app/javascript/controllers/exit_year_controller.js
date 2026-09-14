import { Controller } from "@hotwired/stimulus"

// L'année de revente vit dans l'URL comme l'onglet ouvert, pour que recharger la fiche la
// retrouve. Les flèches du clavier suivent les mêmes liens que celles de l'écran.
export default class extends Controller {
  static targets = ["previous", "next"]

  remember(event) {
    const url = new URL(window.location)

    url.searchParams.set("exit_year", event.params.year)
    history.replaceState(history.state, "", url)
  }

  previous(event) {
    this.step(this.previousTarget, event)
  }

  next(event) {
    this.step(this.nextTarget, event)
  }

  step(link, event) {
    if (!link.href || !this.reachable(event)) return

    event.preventDefault()
    link.click()
  }

  // Ni sous un modificateur, ni dans un champ, ni sous une fiche d'année, ni onglet fermé.
  reachable(event) {
    if (event.metaKey || event.ctrlKey || event.altKey || event.shiftKey) return false
    if (this.element.offsetParent === null || document.querySelector("dialog[open]")) return false

    return !event.target.closest?.("input, select, textarea, [contenteditable]")
  }
}

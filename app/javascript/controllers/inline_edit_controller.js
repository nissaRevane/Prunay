import { Controller } from "@hotwired/stimulus"

// Une valeur de la fiche que le clic ouvre. Le champ s'enregistre dès qu'il change et le
// serveur renvoie la fiche entière : tout y est dérivé, un chiffre corrigé en refait dix.
export default class extends Controller {
  static targets = ["display", "form"]

  open() {
    this.displayTarget.hidden = true
    this.formTarget.hidden = false
    this.field?.focus()
  }

  close() {
    if (this.pending) return

    this.formTarget.hidden = true
    this.displayTarget.hidden = false
  }

  cancel() {
    this.formTarget.reset()
    this.close()
  }

  // Entrée enregistre sans laisser le navigateur soumettre une seconde fois.
  confirm(event) {
    event.preventDefault()
    this.save()
  }

  // requestSubmit refuse de partir sur un champ invalide : la contrainte HTML fait le premier tri.
  save() {
    this.formTarget.requestSubmit()
  }

  lock() {
    this.pending = true
  }

  // Un refus rouvre la porte : le champ garde ce qui a été tapé et redevient annulable.
  release(event) {
    this.pending = event.detail.success
  }

  get field() {
    return this.formTarget.querySelector("input:not([type=hidden]), select")
  }
}

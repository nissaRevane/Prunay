import { Controller } from "@hotwired/stimulus"

// Une valeur de la fiche que le clic ouvre. Le champ s'enregistre dès qu'il change et le
// serveur renvoie la fiche entière : tout y est dérivé, un chiffre corrigé en refait dix.
export default class extends Controller {
  static targets = ["display", "form"]

  // Le clavier ouvre comme le clic, sans dérouler la page, et sur la valeur sélectionnée :
  // ce qu'on tape la remplace au lieu de s'y coller.
  open(event) {
    event?.preventDefault()
    this.displayTarget.hidden = true
    this.formTarget.hidden = false
    this.field?.focus()
    this.field?.select?.()
  }

  close() {
    if (this.pending) return

    this.formTarget.hidden = true
    this.displayTarget.hidden = false
  }

  // Échap abandonne ce qui a été tapé, fût-ce un chiffre que le navigateur refuse.
  cancel() {
    this.pending = false
    this.formTarget.reset()
    this.close()
  }

  // Entrée enregistre sans laisser le navigateur soumettre une seconde fois.
  confirm(event) {
    event.preventDefault()
    this.save()
  }

  // requestSubmit refuse de partir sur un champ invalide : le dire, et garder la porte ouverte —
  // refermer rendrait l'ancienne valeur sans un mot.
  save() {
    if (!this.formTarget.checkValidity()) return this.reject()

    this.syncTab()
    this.formTarget.requestSubmit()
  }

  reject() {
    this.pending = true
    this.formTarget.reportValidity()
  }

  // L'onglet ouvert vit dans l'URL : la fiche renvoyée rouvre celui-là, non celui du rendu.
  syncTab() {
    const tab = new URL(window.location).searchParams.get("tab")
    if (!tab) return

    const action = new URL(this.formTarget.action)

    action.searchParams.set("tab", tab)
    this.formTarget.action = action.toString()
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

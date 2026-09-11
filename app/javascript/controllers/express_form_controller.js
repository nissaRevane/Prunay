import { Controller } from "@hotwired/stimulus"

// La création rapide en pop-in sur la liste : le formulaire répond dans son cadre, si bien
// qu'une réponse manquante ramène ses erreurs dans la modale au lieu de rouvrir l'accueil.
export default class extends Controller {
  static targets = ["dialog"]

  open() {
    this.dialogTarget.showModal()
  }

  close() {
    this.dialogTarget.close()
  }

  // Le clic n'atteint la modale elle-même que par son fond : ailleurs, le formulaire l'a reçu.
  dismiss(event) {
    if (event.target === event.currentTarget) event.currentTarget.close()
  }
}

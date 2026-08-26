import { Controller } from "@hotwired/stimulus"

// Le compte de résultat d'une année de la projection : la ligne cliquée ouvre sa fiche,
// rendue par le serveur, en pop-in modale.
export default class extends Controller {
  static targets = ["statement"]

  open(event) {
    this.statementFor(event.params.year)?.showModal()
  }

  close(event) {
    event.currentTarget.closest("dialog").close()
  }

  // Le clic n'atteint la modale elle-même que par son fond : ailleurs, la fiche l'a reçu.
  dismiss(event) {
    if (event.target === event.currentTarget) event.currentTarget.close()
  }

  statementFor(year) {
    return this.statementTargets.find((statement) => statement.dataset.year === String(year))
  }
}

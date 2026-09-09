import { Controller } from "@hotwired/stimulus"

// Le compte de résultat d'une année de la projection : la ligne cliquée ouvre sa fiche,
// rendue par le serveur, en pop-in modale. Les flèches y passent d'une année à l'autre.
export default class extends Controller {
  static targets = ["statement"]

  open(event) {
    this.statementFor(event.params.year)?.showModal()
  }

  close(event) {
    event.currentTarget.closest("dialog").close()
  }

  navigate(event) {
    this.shift(event.currentTarget.closest("dialog"), event.params.step)
  }

  navigateByKey(event) {
    const step = { ArrowLeft: -1, ArrowRight: 1 }[event.key]
    if (!step) return

    event.preventDefault()
    this.shift(event.currentTarget, step)
  }

  // Le clic n'atteint la modale elle-même que par son fond : ailleurs, la fiche l'a reçu.
  dismiss(event) {
    if (event.target === event.currentTarget) event.currentTarget.close()
  }

  // L'année voisine s'ouvre là où on avait laissé celle-ci : même lecture, même finesse.
  shift(statement, step) {
    const target = this.statementFor(Number(statement.dataset.year) + step)
    if (!target) return

    target.dataset.statementViewValue = statement.dataset.statementViewValue
    target.dataset.statementDetailValue = statement.dataset.statementDetailValue
    statement.close()
    target.showModal()
  }

  statementFor(year) {
    return this.statementTargets.find((statement) => statement.dataset.year === String(year))
  }
}

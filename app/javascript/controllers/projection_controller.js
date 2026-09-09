import { Controller } from "@hotwired/stimulus"

// Le compte de résultat d'une année de la projection : la ligne cliquée demande sa fiche au
// serveur, qui la rend en pop-in modale et la garde. Les flèches y passent d'une année à l'autre.
export default class extends Controller {
  static targets = ["statement", "statements"]
  static values = { url: String }

  async open(event) {
    (await this.statementFor(event.params.year))?.showModal()
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
  async shift(statement, step) {
    const target = await this.statementFor(Number(statement.dataset.year) + step)
    if (!target) return

    target.dataset.statementViewValue = statement.dataset.statementViewValue
    target.dataset.statementDetailValue = statement.dataset.statementDetailValue
    statement.close()
    target.showModal()
  }

  // Une fiche déjà demandée reste dans la page : on ne la redemande pas.
  async statementFor(year) {
    return this.rendered(year) || (await this.fetchStatement(year))
  }

  rendered(year) {
    return this.statementTargets.find((statement) => statement.dataset.year === String(year))
  }

  async fetchStatement(year) {
    const url = new URL(this.urlValue, window.location.origin)
    url.searchParams.set("year", year)

    const response = await fetch(url, { headers: { Accept: "text/html" } })
    if (!response.ok) return null

    this.statementsTarget.insertAdjacentHTML("beforeend", await response.text())

    return this.rendered(year)
  }
}

import { Controller } from "@hotwired/stimulus"

// L'année de revente ne concerne qu'un graphique : le formulaire part au changement et Turbo
// ne remplace que le cadre qui le porte. L'année vit dans l'URL comme l'onglet ouvert, pour
// que recharger la fiche la retrouve.
export default class extends Controller {
  submit(event) {
    this.remember(event.target.value)
    this.element.requestSubmit()
  }

  remember(year) {
    const url = new URL(window.location)

    url.searchParams.set("exit_year", year)
    history.replaceState(history.state, "", url)
  }
}

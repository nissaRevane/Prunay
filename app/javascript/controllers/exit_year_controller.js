import { Controller } from "@hotwired/stimulus"

// L'année de revente ne concerne qu'un graphique : la flèche navigue dans le cadre qui la porte
// et Turbo ne remplace que lui. L'année vit dans l'URL comme l'onglet ouvert, pour que recharger
// la fiche la retrouve.
export default class extends Controller {
  remember(event) {
    const url = new URL(window.location)

    url.searchParams.set("exit_year", event.params.year)
    history.replaceState(history.state, "", url)
  }
}

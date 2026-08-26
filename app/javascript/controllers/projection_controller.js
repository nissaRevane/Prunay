import { Controller } from "@hotwired/stimulus"

// Le détail d'une année de la projection : la ligne suivante, cachée, se déplie au clic.
export default class extends Controller {
  toggle(event) {
    const row = event.currentTarget
    const detail = row.nextElementSibling
    const button = row.querySelector(".row-toggle")
    const opened = detail.hidden

    detail.hidden = !opened
    row.classList.toggle("is-open", opened)
    button.setAttribute("aria-expanded", opened)
  }
}

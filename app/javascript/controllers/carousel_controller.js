import { Controller } from "@hotwired/stimulus"

// Un cadre, plusieurs vues : une seule est visible, les flèches tournent en boucle.
export default class extends Controller {
  static targets = ["slide", "title"]
  static values = { index: Number }

  previous() {
    this.indexValue = (this.indexValue - 1 + this.slideTargets.length) % this.slideTargets.length
  }

  next() {
    this.indexValue = (this.indexValue + 1) % this.slideTargets.length
  }

  indexValueChanged() {
    this.slideTargets.forEach((slide, index) => { slide.hidden = index !== this.indexValue })
    if (this.hasTitleTarget) this.titleTarget.textContent = this.slideTargets[this.indexValue].dataset.title
  }
}

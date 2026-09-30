import { Controller } from "@hotwired/stimulus"

// Le loyer estimé s'affiche en indication dans le champ, jamais en valeur : laissé vide,
// le loyer est celui que le serveur propose, et ce qui a été tapé n'est jamais recouvert.
const DELAY = 300

const ANSWERS = ["simulation[property_type]", "simulation[city]", "simulation[surface]"]

export default class extends Controller {
  static targets = ["frame", "rent"]
  static values = { url: String }

  connect() {
    this.blank = this.rentTarget.placeholder
    this.#propose()
  }

  disconnect() {
    clearTimeout(this.timer)
  }

  estimate() {
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.#load(), DELAY)
  }

  propose(event) {
    if (event.target === this.frameTarget) this.#propose()
  }

  #propose() {
    const estimate = this.frameTarget.querySelector("[data-rent-estimate-placeholder]")
    this.rentTarget.placeholder = estimate?.dataset.rentEstimatePlaceholder || this.blank
  }

  #load() {
    const answers = new FormData(this.element)
    const [type, city, surface] = ANSWERS.map((name) => (answers.get(name) || "").trim())

    if (!city || !surface) return this.#clear()

    const url = new URL(this.urlValue, window.location.origin)

    Object.entries({ property_type: type, city: city, surface: surface })
      .forEach(([key, value]) => url.searchParams.set(key, value))

    this.frameTarget.src = url.toString()
  }

  #clear() {
    this.frameTarget.removeAttribute("src")
    this.frameTarget.replaceChildren()
    this.#propose()
  }
}

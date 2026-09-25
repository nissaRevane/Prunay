import { Controller } from "@hotwired/stimulus"

// Le loyer du marché sous le champ, dès que la ville et la surface sont là. Il ne remplit
// qu'un champ resté vide : une estimation ne recouvre jamais une réponse déjà donnée.
const DELAY = 300

const ANSWERS = ["simulation[property_type]", "simulation[city]", "simulation[surface]"]

export default class extends Controller {
  static targets = ["frame", "rent"]
  static values = { url: String }

  connect() {
    this.answered = this.rentTarget.value.trim() !== ""
  }

  disconnect() {
    clearTimeout(this.timer)
  }

  lock() {
    this.answered = true
  }

  estimate() {
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.#load(), DELAY)
  }

  fill(event) {
    if (event.target !== this.frameTarget) return

    const amount = this.frameTarget.querySelector("[data-rent-estimate-amount]")?.dataset.rentEstimateAmount
    if (!amount || this.answered || this.rentTarget.value.trim() !== "") return

    this.rentTarget.value = amount
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
  }
}

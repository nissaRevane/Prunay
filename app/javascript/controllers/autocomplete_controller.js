import { Controller } from "@hotwired/stimulus"

// La saisie assistée d'une ville puis d'une adresse, contre la Base Adresse Nationale. Une
// suggestion retenue vaut saisie : ailleurs sur la fiche, elle enregistre comme une frappe.
const ENDPOINT = "https://api-adresse.data.gouv.fr/search/"
const LIMIT = 5

const fold = (text) => text.normalize("NFD").replace(/\p{Diacritic}/gu, "").toLowerCase().trim()

export default class extends Controller {
  static targets = ["input", "list"]
  static values = {
    type: String,
    cityField: String,
    minimum: { type: Number, default: 3 },
    delay: { type: Number, default: 250 }
  }

  connect() {
    this.results = []
    this.active = -1
  }

  disconnect() {
    clearTimeout(this.timer)
    this.request?.abort()
  }

  search() {
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.#load(), this.delayValue)
  }

  navigate(event) {
    if (!this.opened) return

    switch (event.key) {
      case "ArrowDown": return this.#step(event, 1)
      case "ArrowUp": return this.#step(event, -1)
      case "Enter": return this.#confirm(event)
      case "Escape": return this.#dismiss(event)
    }
  }

  // Le clic ne doit pas sortir du champ : en sortir refermerait la liste.
  pick(event) {
    const option = event.target.closest("[data-index]")
    if (!option) return

    event.preventDefault()
    this.#apply(this.results[Number(option.dataset.index)])
  }

  close() {
    clearTimeout(this.timer)
    this.listTarget.hidden = true
    this.listTarget.replaceChildren()
    this.inputTarget.setAttribute("aria-expanded", "false")
    this.inputTarget.removeAttribute("aria-activedescendant")
    this.results = []
    this.active = -1
  }

  get opened() {
    return this.results.length > 0
  }

  async #load() {
    const query = this.inputTarget.value.trim()
    if (query.length < this.minimumValue) return this.close()

    this.request?.abort()
    this.request = new AbortController()

    try {
      const response = await fetch(this.#url(query), { signal: this.request.signal })
      if (!response.ok) return this.close()

      const { features } = await response.json()
      this.#render(this.#suggestions(features))
    } catch (error) {
      if (error.name !== "AbortError") this.close()
    }
  }

  #url(query) {
    const url = new URL(ENDPOINT)
    const parameters = { q: [query, this.#city].filter(Boolean).join(" "), type: this.typeValue,
                         autocomplete: "1", limit: LIMIT }

    Object.entries(parameters).forEach(([key, value]) => url.searchParams.set(key, value))

    return url
  }

  // On ne restreint à la commune que si ça laisse quelque chose à proposer.
  #suggestions(features) {
    const found = features.map(({ properties }) => ({
      value: this.typeValue === "municipality" ? properties.city : properties.name,
      label: properties.label,
      context: properties.context,
      city: properties.city
    }))

    const city = this.#city
    if (!city) return found

    const local = found.filter((suggestion) => fold(suggestion.city) === fold(city))

    return local.length > 0 ? local : found
  }

  #render(suggestions) {
    this.results = suggestions
    this.active = -1

    if (suggestions.length === 0) return this.close()

    this.listTarget.replaceChildren(...suggestions.map((suggestion, index) => this.#option(suggestion, index)))
    this.listTarget.hidden = false
    this.inputTarget.setAttribute("aria-expanded", "true")
    this.inputTarget.removeAttribute("aria-activedescendant")
  }

  #option(suggestion, index) {
    const option = document.createElement("li")

    option.className = "autocomplete-option"
    option.id = `${this.listTarget.id}_${index}`
    option.dataset.index = index
    option.setAttribute("role", "option")
    option.setAttribute("aria-selected", "false")
    option.append(suggestion.label)

    if (suggestion.context) {
      const context = document.createElement("span")

      context.className = "autocomplete-context"
      context.textContent = suggestion.context
      option.append(context)
    }

    return option
  }

  #step(event, direction) {
    event.preventDefault()

    const count = this.results.length
    const next = this.active < 0 ? (direction > 0 ? 0 : count - 1)
                                 : (this.active + direction + count) % count

    this.#highlight(next)
  }

  #highlight(index) {
    this.#options.forEach((option, position) => {
      option.setAttribute("aria-selected", String(position === index))
    })

    this.active = index
    this.inputTarget.setAttribute("aria-activedescendant", this.#options[index].id)
  }

  // Entrée sans suggestion retenue appartient au formulaire.
  #confirm(event) {
    if (this.active < 0) return

    event.preventDefault()
    event.stopPropagation()
    this.#apply(this.results[this.active])
  }

  #dismiss(event) {
    event.preventDefault()
    event.stopPropagation()
    this.close()
  }

  #apply(suggestion) {
    this.inputTarget.value = suggestion.value
    this.close()
    this.inputTarget.dispatchEvent(new Event("change", { bubbles: true }))
  }

  get #options() {
    return Array.from(this.listTarget.children)
  }

  get #city() {
    if (this.typeValue === "municipality") return ""

    return document.querySelector(this.cityFieldValue)?.value.trim() || ""
  }
}

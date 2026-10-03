import { Controller } from "@hotwired/stimulus"

const NUMBER = new Intl.NumberFormat("fr-FR")

// Les lots d'un immeuble : la surface se dit avec le bien, le reste avec la location. Tant
// qu'il reste un lot, les champs de l'immeuble en montrent le total, sans le laisser saisir.
export default class extends Controller {
  static targets = ["type", "editor", "template", "list", "row", "surface",
                    "lettingTemplate", "lettingList", "lettingRow", "rent", "charges", "months",
                    "totalSurface", "totalRent", "totalCharges", "totalMonths"]
  static values = { building: String, number: String, surface: String }

  connect() {
    this.nextIndex = this.rowTargets.length
    this.refresh()
  }

  add() {
    const index = this.nextIndex++

    this.listTarget.insertAdjacentHTML("beforeend", this.#fill(this.templateTarget, index))
    if (this.hasLettingTemplateTarget) {
      this.lettingListTarget.insertAdjacentHTML("beforeend", this.#fill(this.lettingTemplateTarget, index))
    }
    this.surfaceTargets.at(-1).focus()
    this.refresh()
  }

  remove(event) {
    const index = event.currentTarget.closest("[data-index]").dataset.index

    this.element.querySelectorAll(`[data-index="${index}"]`).forEach((row) => row.remove())
    this.refresh()
  }

  refresh() {
    const building = !this.hasTypeTarget || this.typeTarget.value === this.buildingValue

    this.editorTargets.forEach((editor) => {
      editor.hidden = !building
      editor.querySelectorAll("input").forEach((input) => { input.disabled = !building })
    })

    this.#number(this.rowTargets)
    this.#number(this.lettingRowTargets)
    this.#describe()

    const divided = building && this.rowTargets.length + this.lettingRowTargets.length > 0
    this.#total(this.totalSurfaceTargets, divided, () => this.#sum(this.surfaceTargets))
    this.#total(this.totalRentTargets, divided, () => this.#sum(this.rentTargets))
    this.#total(this.totalChargesTargets, divided, () => this.#sum(this.chargesTargets))
    this.#total(this.totalMonthsTargets, divided, () => this.#months())
  }

  #fill(template, index) {
    return template.innerHTML.replaceAll("__INDEX__", index)
  }

  #number(rows) {
    rows.forEach((row, position) => {
      row.querySelector("[data-lots-number]").textContent = this.numberValue.replace("%{number}", position + 1)
    })
  }

  #describe() {
    this.lettingRowTargets.forEach((row) => {
      const surface = this.surfaceTargets.find((input) => input.closest("[data-index]").dataset.index === row.dataset.index)
      if (!surface) return

      const value = parseFloat(surface.value)
      row.querySelector("[data-lots-surface]").textContent =
        value > 0 ? this.surfaceValue.replace("%{surface}", NUMBER.format(value)) : ""
    })
  }

  #total(fields, divided, compute) {
    fields.forEach((field) => {
      field.disabled = divided
      if (divided) field.value = compute()
    })
  }

  #sum(inputs) {
    return Math.round(inputs.reduce((total, input) => total + this.#value(input), 0) * 100) / 100
  }

  // Les mois de chaque lot pèsent son loyer, comme Simulation#occupancy_months.
  #months() {
    const rent = this.#sum(this.rentTargets)
    const months = this.monthsTargets.map((input) => this.#value(input))
    const average = rent > 0
      ? this.rentTargets.reduce((total, input, index) => total + this.#value(input) * months[index], 0) / rent
      : months.reduce((total, value) => total + value, 0) / months.length

    return Math.round(average * 10) / 10
  }

  #value(input) {
    return parseFloat(input.value) || 0
  }
}

import { Controller } from "@hotwired/stimulus"

const NUMBER = new Intl.NumberFormat("fr-FR")

// Les lots d'un immeuble : la surface se dit avec le bien, le loyer avec la location. Tant
// qu'il reste un lot, la surface et le loyer de l'immeuble en sont la somme, non saisie.
export default class extends Controller {
  static targets = ["type", "editor", "template", "list", "row", "surface",
                    "rentTemplate", "rentList", "rentRow", "rent", "totalSurface", "totalRent"]
  static values = { building: String, number: String, surface: String }

  connect() {
    this.nextIndex = this.rowTargets.length
    this.refresh()
  }

  add() {
    const index = this.nextIndex++

    this.listTarget.insertAdjacentHTML("beforeend", this.#fill(this.templateTarget, index))
    if (this.hasRentTemplateTarget) {
      this.rentListTarget.insertAdjacentHTML("beforeend", this.#fill(this.rentTemplateTarget, index))
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
    this.#number(this.rentRowTargets)
    this.#describe()

    const divided = building && this.rowTargets.length + this.rentRowTargets.length > 0
    this.#total(this.totalSurfaceTargets, this.surfaceTargets, divided)
    this.#total(this.totalRentTargets, this.rentTargets, divided)
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
    this.rentRowTargets.forEach((row) => {
      const surface = this.surfaceTargets.find((input) => input.closest("[data-index]").dataset.index === row.dataset.index)
      if (!surface) return

      const value = parseFloat(surface.value)
      row.querySelector("[data-lots-surface]").textContent =
        value > 0 ? this.surfaceValue.replace("%{surface}", NUMBER.format(value)) : ""
    })
  }

  #total(fields, inputs, divided) {
    const sum = inputs.reduce((total, input) => total + (parseFloat(input.value) || 0), 0)

    fields.forEach((field) => {
      field.disabled = divided
      if (divided) field.value = Math.round(sum * 100) / 100
    })
  }
}

import { Controller } from "@hotwired/stimulus"

// Les lots d'un immeuble : tant qu'il en reste un, la surface et le loyer en sont la somme,
// montrée sans être saisie.
export default class extends Controller {
  static targets = ["type", "editor", "list", "template", "row", "surface", "rent", "totalSurface", "totalRent"]
  static values = { building: String }

  connect() {
    this.refresh()
  }

  add() {
    this.listTarget.insertAdjacentHTML("beforeend", this.templateTarget.innerHTML)
    this.surfaceTargets.at(-1).focus()
    this.refresh()
  }

  remove(event) {
    event.currentTarget.closest("[data-lots-target='row']").remove()
    this.refresh()
  }

  refresh() {
    const building = this.typeTarget.value === this.buildingValue

    this.editorTarget.hidden = !building
    this.editorTarget.querySelectorAll("input").forEach((input) => { input.disabled = !building })

    const divided = building && this.rowTargets.length > 0
    this.#total(this.totalSurfaceTargets, this.surfaceTargets, divided)
    this.#total(this.totalRentTargets, this.rentTargets, divided)
  }

  #total(fields, inputs, divided) {
    const sum = inputs.reduce((total, input) => total + (parseFloat(input.value) || 0), 0)

    fields.forEach((field) => {
      field.disabled = divided
      if (divided) field.value = Math.round(sum * 100) / 100
    })
  }
}

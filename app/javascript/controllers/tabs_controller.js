import { Controller } from "@hotwired/stimulus"

// Les panneaux d'une simulation sont tous rendus par le serveur — l'onglet ne fait que choisir
// lequel se montre, sans aller-retour. Les régimes fiscaux partagent un onglet, et sa liste
// déroulante les départage : le nom du régime choisi devient celui de l'onglet.
export default class extends Controller {
  static targets = ["tab", "panel", "regimeToggle", "regimeLabel", "options", "option"]
  static values = { name: String }

  connect() {
    this.render()
  }

  select(event) {
    const name = event.currentTarget.dataset.tabName

    if (this.isRegimeToggle(event.currentTarget) && name === this.nameValue) return this.toggleOptions()

    this.closeOptions()
    this.nameValue = name
    this.rememberTab(name)
  }

  // L'onglet ouvert vit dans l'URL : recharger la page rouvre le même.
  rememberTab(name) {
    const url = new URL(window.location)

    url.searchParams.set("tab", name)
    history.replaceState(history.state, "", url)
  }

  toggleOptions() {
    this.optionsTarget.hidden = !this.optionsTarget.hidden
    this.regimeToggleTarget.setAttribute("aria-expanded", !this.optionsTarget.hidden)
  }

  closeOptions() {
    if (!this.hasOptionsTarget || this.optionsTarget.hidden) return

    this.optionsTarget.hidden = true
    this.regimeToggleTarget.setAttribute("aria-expanded", "false")
  }

  // La liste recouvre le panneau : un clic ailleurs la referme.
  closeOutside(event) {
    if (this.element.contains(event.target)) return

    this.closeOptions()
  }

  nameValueChanged() {
    this.render()
  }

  render() {
    this.showRegime()
    this.showPanel()
  }

  // L'onglet fiscal prend le nom, le libellé et le panneau du régime choisi.
  showRegime() {
    if (!this.hasRegimeToggleTarget) return

    const chosen = this.optionTargets.find((option) => option.dataset.tabName === this.nameValue)

    this.optionTargets.forEach((option) => option.setAttribute("aria-checked", option === chosen))
    if (!chosen) return

    this.regimeToggleTarget.dataset.tabName = this.nameValue
    this.regimeToggleTarget.id = `tab-${this.nameValue}`
    this.regimeToggleTarget.setAttribute("aria-controls", `panel-${this.nameValue}`)
    this.regimeLabelTarget.textContent = chosen.textContent.trim()
  }

  showPanel() {
    this.tabTargets.forEach((tab) => {
      const current = tab.dataset.tabName === this.nameValue

      tab.classList.toggle("is-active", current)
      tab.setAttribute("aria-selected", current)
      tab.setAttribute("tabindex", current ? "0" : "-1")
    })

    this.panelTargets.forEach((panel) => {
      panel.hidden = panel.dataset.tabName !== this.nameValue
    })
  }

  isRegimeToggle(element) {
    return this.hasRegimeToggleTarget && element === this.regimeToggleTarget
  }
}

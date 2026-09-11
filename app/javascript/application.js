import { Turbo } from "@hotwired/turbo-rails"
import "controllers"

// Un formulaire posé dans un cadre y garde ses erreurs : pour ouvrir la simulation créée, il
// faut une action de flux qui, elle, quitte le cadre.
Turbo.StreamActions.redirect = function () {
  Turbo.visit(this.getAttribute("target"))
}

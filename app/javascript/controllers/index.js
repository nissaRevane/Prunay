import { application } from "controllers/application"

import AlertController from "controllers/alert_controller"
application.register("alert", AlertController)

import AutocompleteController from "controllers/autocomplete_controller"
application.register("autocomplete", AutocompleteController)

import CarouselController from "controllers/carousel_controller"
application.register("carousel", CarouselController)

import CreditController from "controllers/credit_controller"
application.register("credit", CreditController)

import ExitYearController from "controllers/exit_year_controller"
application.register("exit-year", ExitYearController)

import ExpressFormController from "controllers/express_form_controller"
application.register("express-form", ExpressFormController)

import InlineEditController from "controllers/inline_edit_controller"
application.register("inline-edit", InlineEditController)

import LoanController from "controllers/loan_controller"
application.register("loan", LoanController)

import NavbarController from "controllers/navbar_controller"
application.register("navbar", NavbarController)

import NotaryFeesController from "controllers/notary_fees_controller"
application.register("notary-fees", NotaryFeesController)

import ProjectionController from "controllers/projection_controller"
application.register("projection", ProjectionController)

import RentEstimateController from "controllers/rent_estimate_controller"
application.register("rent-estimate", RentEstimateController)

import StatementController from "controllers/statement_controller"
application.register("statement", StatementController)

import TabsController from "controllers/tabs_controller"
application.register("tabs", TabsController)

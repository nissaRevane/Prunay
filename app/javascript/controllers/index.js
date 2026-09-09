import { application } from "controllers/application"

import AlertController from "controllers/alert_controller"
application.register("alert", AlertController)

import CreditController from "controllers/credit_controller"
application.register("credit", CreditController)

import ExitYearController from "controllers/exit_year_controller"
application.register("exit-year", ExitYearController)

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

import StatementController from "controllers/statement_controller"
application.register("statement", StatementController)

import TabsController from "controllers/tabs_controller"
application.register("tabs", TabsController)

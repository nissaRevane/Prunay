import { application } from "controllers/application"

import AlertController from "controllers/alert_controller"
application.register("alert", AlertController)

import ChargesController from "controllers/charges_controller"
application.register("charges", ChargesController)

import NotaryFeesController from "controllers/notary_fees_controller"
application.register("notary-fees", NotaryFeesController)

import TabsController from "controllers/tabs_controller"
application.register("tabs", TabsController)

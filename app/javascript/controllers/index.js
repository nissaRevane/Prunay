import { application } from "controllers/application"

import AlertController from "controllers/alert_controller"
application.register("alert", AlertController)

import NotaryFeesController from "controllers/notary_fees_controller"
application.register("notary-fees", NotaryFeesController)

import TabsController from "controllers/tabs_controller"
application.register("tabs", TabsController)

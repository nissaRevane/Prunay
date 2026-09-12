require "active_support/core_ext/integer/time"

Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = true
  config.consider_all_requests_local = true
  config.action_controller.perform_caching = true
  # En mémoire plutôt que nulle part : sans compteur, aucune limite ne se laisserait éprouver.
  config.cache_store = :memory_store
  config.active_support.deprecation = :log
  config.active_support.disallowed_deprecations = :raise
  config.active_record.migration_error = :page_load
  config.action_mailer.delivery_method = :test
  config.action_mailer.default_url_options = { host: "localhost", port: 3001 }

  # Request specs post without a CSRF token, and specs assert on raised
  # exceptions rather than on the rendered error pages.
  config.action_controller.allow_forgery_protection = false
  config.action_dispatch.show_exceptions = :none
end

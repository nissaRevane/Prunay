class ApplicationController < ActionController::Base
  # Un compteur par IP ; les formulaires ont la leur, plus serrée.
  REQUESTS_PER_MINUTE = 300

  before_action :authenticate_user!

  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found

  # Un dépassement renvoie d'où il vient : un 429 nu n'apprendrait rien.
  def self.throttle(name:, to:, within:, **options)
    rate_limit(name: name, to: to, within: within, **options,
               with: lambda {
                 redirect_back fallback_location: root_path, status: :see_other,
                               alert: t("flash.errors.throttled")
               })
  end

  throttle name: "requests", to: REQUESTS_PER_MINUTE, within: 1.minute

  protected

  def render_not_found
    respond_to do |format|
      format.html { redirect_back fallback_location: root_path, alert: t("flash.errors.not_found") }
      format.any  { head :not_found }
    end
  end
end

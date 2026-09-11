class ApplicationController < ActionController::Base
  before_action :authenticate_user!

  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found

  protected

  def render_not_found
    respond_to do |format|
      format.html { redirect_back fallback_location: root_path, alert: t("flash.errors.not_found") }
      format.any  { head :not_found }
    end
  end
end

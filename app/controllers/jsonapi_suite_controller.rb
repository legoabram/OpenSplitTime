class JsonapiSuiteController < ApplicationController
  include JsonapiSuite::ControllerMixin

  skip_before_action :verify_authenticity_token, if: :json_web_token_present?
  before_action :apply_strong_params, only: [:create, :update]
  before_action :authenticate_user!
  after_action :verify_authorized

  register_exception JsonapiCompliable::Errors::RecordNotFound,
                     status: 404,
                     message: ->(e) { e }

  register_exception Pundit::NotAuthorizedError,
                     status: 401,
                     message: ->(_) { 'You need to sign in or sign up before continuing' }

  rescue_from Exception do |e|
    handle_exception(e)
  end

  private

  def editable?
    params.dig(:filter, :editable)&.to_boolean
  end

  def raise_not_found
    raise JsonapiCompliable::Errors::RecordNotFound,
          "Could not find #{controller_class_name} with id #{params[:id]}"
  end
end

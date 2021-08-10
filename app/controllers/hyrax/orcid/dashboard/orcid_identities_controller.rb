# frozen_string_literal: true

module Hyrax
  module Orcid
    module Dashboard
      class OrcidIdentitiesController < ApplicationController
        include Hyrax::Orcid::RouteHelper

        with_themed_layout "dashboard"
        before_action :authenticate_user!

        def new
          request_authorization

          if authorization_successful?
            current_user.orcid_identity_from_authorization(authorization_body)
            flash[:notice] = I18n.t("orcid_identity.preferences.create.success")
          else
            flash[:error] = I18n.t("orcid_identity.preferences.create.failure", error: authorization_body.dig("error"))
          end

          redirect_to hyrax_routes.dashboard_profile_path(current_user)
        end

        def update
          if current_user.orcid_identity.update(permitted_preference_params)
            flash[:notice] = I18n.t("orcid_identity.preferences.update.success")
          else
            flash[:error] = I18n.t("orcid_identity.preferences.update.failure")
          end

          redirect_back fallback_location: hyrax_routes.dashboard_profile_path(current_user)
        end

        def destroy
          # This is pretty ugly, but for a has_one relation we can't do a find_by! from User
          raise ActiveRecord::RecordNotFound unless current_user.orcid_identity&.id == params["id"].to_i

          current_user.orcid_identity.destroy
          flash[:notice] = I18n.t("orcid_identity.preferences.destroy.success")

          redirect_back fallback_location: hyrax_routes.dashboard_profile_path(current_user)
        end

        protected

        def permitted_preference_params
          params.require(:orcid_identity).permit(:work_sync_preference, profile_sync_preference: {})
        end

        def request_authorization
          # TODO: Put these in an options panel
          data = {
            client_id: ENV["ORCID_CLIENT_ID"],
            client_secret: ENV["ORCID_CLIENT_SECRET"],
            grant_type: "authorization_code",
            code: code
          }

          @authorization_response = Faraday.post(helpers.orcid_token_uri, data.to_query, "Accept" => "application/json")
        end

        def authorization_successful?
          @authorization_response.success?
        end

        def authorization_body
          JSON.parse(@authorization_response.body)
        end

        def code
          params.require(:code)
        end
      end
    end
  end
end
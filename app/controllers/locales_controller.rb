# ABOUTME: Persists the demo reader's explicit interface-language selection.
# ABOUTME: Rejects unsupported locale values before they reach application state.
class LocalesController < ApplicationController
  def update
    locale = params[:locale].to_s
    return head(:unprocessable_content) unless available_locales.include?(locale)

    current_user.update!(locale:)
    session[:locale] = locale
    redirect_back fallback_location: root_path
  end
end

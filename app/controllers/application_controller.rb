class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  around_action :use_locale
  helper_method :current_user, :available_locales

  private

  def current_user
    @current_user ||= User.first_or_create!(name: "デモ読者", locale: "ja")
  end

  def available_locales
    I18n.available_locales.map(&:to_s)
  end

  def use_locale(&action)
    requested = params[:locale].presence
    locale = [ requested, session[:locale], current_user.locale, I18n.default_locale ].find { |value| available_locales.include?(value.to_s) }
    I18n.with_locale(locale, &action)
  end
end

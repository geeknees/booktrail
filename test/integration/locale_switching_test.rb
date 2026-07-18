# ABOUTME: Verifies that the demo reader can switch the complete interface language.
# ABOUTME: Keeps the selected locale durable across requests and background work.
require "test_helper"

class LocaleSwitchingTest < ActionDispatch::IntegrationTest
  test "switches from Japanese to English and persists the reader locale" do
    get root_path
    assert_select "html[lang='ja']"
    assert_select "a", text: "履歴を取り込む"

    patch locale_path, params: { locale: "en" }

    assert_redirected_to root_path
    assert_equal "en", User.first.locale

    get root_path
    assert_select "html[lang='en']"
    assert_select "a", text: "Import history"
    assert_select "option[selected]", text: "English"

    get new_import_path
    assert_select "h1", text: "Import your reading trail"

    get reading_profile_path
    assert_select "h1", text: "Reading profile"

    get new_recommendation_session_path
    assert_select "h1", text: "What would you like to read now?"
  end

  test "rejects unsupported locales" do
    patch locale_path, params: { locale: "unsupported" }

    assert_response :unprocessable_content
  end
end

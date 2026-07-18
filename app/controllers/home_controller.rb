# ABOUTME: Renders the product promise and entry points for the demo reader.
# ABOUTME: Keeps the landing page free of recommendation business logic.
class HomeController < ApplicationController
  def show
    @record_count = current_user.reading_records.count
  end
end

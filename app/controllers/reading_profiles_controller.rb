# ABOUTME: Presents the reader-safe summary inferred from imported history.
# ABOUTME: Regenerates the profile explicitly so the view reflects current records.
class ReadingProfilesController < ApplicationController
  def show
    @profile = ReadingProfileGenerator.new(user: current_user).call
  end
end

# ABOUTME: Validates and coordinates private Booklog CSV uploads.
# ABOUTME: Never persists the uploaded file after row processing completes.
class ImportsController < ApplicationController
  MAX_FILE_SIZE = 5.megabytes
  ALLOWED_CONTENT_TYPES = %w[text/csv application/csv application/vnd.ms-excel text/plain].freeze

  def new; end

  def create
    upload = params.dig(:import, :file)
    return render_invalid("CSVファイルを選択してください。") unless valid_upload?(upload)

    @import = BooklogCsvImporter.new(user: current_user, file: upload.tempfile, filename: upload.original_filename).call
    ReadingProfileGenerator.new(user: current_user).call unless @import.status == "failed"
    redirect_to @import
  end

  def show
    @import = current_user.imports.find(params[:id])
  end

  private

  def valid_upload?(upload)
    upload.present? && File.extname(upload.original_filename).downcase == ".csv" && upload.size <= MAX_FILE_SIZE && ALLOWED_CONTENT_TYPES.include?(upload.content_type)
  end

  def render_invalid(message)
    flash.now[:alert] = message
    render :new, status: :unprocessable_content
  end
end

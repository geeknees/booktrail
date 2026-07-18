# ABOUTME: Refreshes QMD after the public recommendation catalog changes.
# ABOUTME: Uses fixed argument arrays and a bounded collection name without a shell.
require "open3"
require "timeout"

class QmdCatalogIndexer
  TIMEOUT_SECONDS = 5.minutes

  def initialize(document_writer: QmdBookDocumentWriter.new, process_executor: Open3.method(:capture3))
    @document_writer = document_writer
    @process_executor = process_executor
  end

  def call
    @document_writer.call
    run("update")
    run("embed", "-c", collection)
  end

  private

  def run(*arguments)
    environment = ENV["QMD_EMBED_MODEL"].present? ? { "QMD_EMBED_MODEL" => ENV["QMD_EMBED_MODEL"] } : {}
    _output, error_output, status = Timeout.timeout(TIMEOUT_SECONDS) { @process_executor.call(environment, "qmd", *arguments) }
    raise "QMD catalog refresh failed: #{error_output.to_s.lines.first.to_s.strip}" unless status.success?
  end

  def collection
    value = ENV.fetch("QMD_COLLECTION", "booktrail")
    value.match?(/\A[a-z0-9_-]+\z/i) ? value : "booktrail"
  end
end

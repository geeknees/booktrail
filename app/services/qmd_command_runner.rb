# ABOUTME: Executes the allowlisted QMD search commands without a shell.
# ABOUTME: Applies bounded arguments, timeout handling, and JSON validation.
require "json"
require "open3"
require "timeout"

class QmdCommandRunner
  COMMANDS = %w[search vsearch query].freeze
  TIMEOUT_SECONDS = 45

  def initialize(process_executor: Open3.method(:capture3))
    @process_executor = process_executor
  end

  def call(command:, query:, limit:, collection:)
    raise ArgumentError, "Unsupported QMD command" unless COMMANDS.include?(command)
    raise ArgumentError, "Invalid QMD collection" unless collection.match?(/\A[a-z0-9_-]+\z/i)

    result_limit = limit.to_i.clamp(1, 100)
    arguments = [ "qmd", command, "--json", "--explain", "-n", result_limit.to_s, "-c", collection ]
    arguments.push("-C", result_limit.to_s) if command == "query"
    arguments << query.to_s.squish
    environment = ENV["QMD_EMBED_MODEL"].present? ? { "QMD_EMBED_MODEL" => ENV["QMD_EMBED_MODEL"] } : {}
    output, error_output, status = Timeout.timeout(TIMEOUT_SECONDS) { @process_executor.call(environment, *arguments) }
    raise "QMD #{command} failed: #{error_output.to_s.lines.first.to_s.strip}" unless status.success?

    parsed = JSON.parse(output)
    raise JSON::ParserError, "QMD result must be an array" unless parsed.is_a?(Array)

    parsed
  end
end

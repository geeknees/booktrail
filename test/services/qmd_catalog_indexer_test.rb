# ABOUTME: Verifies safe QMD corpus refresh after public catalog discovery.
# ABOUTME: Keeps update and embedding commands shell-free and collection-bounded.
require "test_helper"

class QmdCatalogIndexerTest < ActiveSupport::TestCase
  Writer = Struct.new(:calls) do
    def call
      self.calls += 1
    end
  end
  Status = Struct.new(:success?)

  test "writes documents and refreshes the configured QMD collection" do
    writer = Writer.new(0)
    commands = []
    executor = ->(_environment, *arguments) {
      commands << arguments
      [ "", "", Status.new(true) ]
    }

    QmdCatalogIndexer.new(document_writer: writer, process_executor: executor).call

    assert_equal 1, writer.calls
    assert_equal [ [ "qmd", "update" ], [ "qmd", "embed", "-c", "booktrail" ] ], commands
  end
end

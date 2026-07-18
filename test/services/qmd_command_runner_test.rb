# ABOUTME: Verifies the bounded, shell-free QMD process invocation contract.
# ABOUTME: Keeps expensive hybrid reranking limited without altering other search modes.
require "test_helper"

class QmdCommandRunnerTest < ActiveSupport::TestCase
  Status = Struct.new(:success?)

  test "limits candidates reranked by a hybrid query" do
    captured_arguments = nil
    executor = ->(_environment, *arguments) {
      captured_arguments = arguments
      [ "[]", "", Status.new(true) ]
    }
    QmdCommandRunner.new(process_executor: executor).call(command: "query", query: "科学の物語", limit: 12, collection: "booktrail")

    assert_equal [ "-C", "12" ], captured_arguments.slice(captured_arguments.index("-C"), 2)
    assert_equal "科学の物語", captured_arguments.last
  end

  test "does not pass a reranker option to vector search" do
    captured_arguments = nil
    executor = ->(_environment, *arguments) {
      captured_arguments = arguments
      [ "[]", "", Status.new(true) ]
    }
    QmdCommandRunner.new(process_executor: executor).call(command: "vsearch", query: "科学\n宇宙", limit: 8, collection: "booktrail")

    refute_includes captured_arguments, "-C"
    assert_equal "科学 宇宙", captured_arguments.last
  end
end

# ABOUTME: Emits one compact Markdown search document per catalog book.
# ABOUTME: Uses database-owned identifiers for filenames to prevent path traversal.
require "fileutils"

class QmdBookDocumentWriter
  DIRECTORY = Rails.root.join("tmp/qmd/books")

  def call
    FileUtils.mkdir_p(DIRECTORY)
    expected_files = []
    Book.recommendable.find_each do |book|
      expected_files << filename(book)
      File.write(DIRECTORY.join(filename(book)), document(book))
    end
    prune_stale_documents(expected_files)
  end

  private

  def filename(book)
    "#{book.isbn.presence || "book-#{book.id}"}.md"
  end

  def document(book)
    <<~MARKDOWN
      ---
      isbn: #{book.isbn.to_json}
      title: #{book.title.to_json}
      author: #{book.author.to_json}
      pages: #{book.page_count.to_json}
      genres: #{book.categories.to_json}
      language: #{book.language.to_json}
      ---

      # #{book.title}

      #{book.description.presence || [ book.author, book.publisher, *book.categories ].compact.join('。')}
    MARKDOWN
  end

  def prune_stale_documents(expected_files)
    Dir.glob(DIRECTORY.join("*.md")).each do |path|
      basename = File.basename(path)
      next unless basename.match?(/\A(?:\d{10,13}|book-\d+)\.md\z/)
      File.delete(path) unless expected_files.include?(basename)
    end
  end
end

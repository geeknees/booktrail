# ABOUTME: Builds Booktrail's compact QMD corpus and documents safe CLI setup steps.
# ABOUTME: Keeps model downloads and index mutation explicit developer operations.
namespace :qmd do
  desc "Write one Markdown search document per catalog book"
  task documents: :environment do
    QmdBookDocumentWriter.new.call
    puts "Wrote #{Book.count} documents to tmp/qmd/books"
  end
end

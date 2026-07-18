# Booktrail architecture decisions

## Candidate boundary

All candidate sources implement this contract:

```ruby
class RecommendationCandidateProvider
  def candidates(user:, profile:, goal:, intent:, limit:)
    raise NotImplementedError
  end
end
```

The MVP has deterministic local scoring and a QMD CLI adapter. A future `CollaborativeFilteringCandidateProvider` belongs at this boundary only after explicit consent and enough cross-user interactions exist.

## Ranking stages

1. Persist a pending recommendation session and enqueue `RecommendationGenerationJob` through Solid Queue.
2. With explicit consent, discover public candidates from a bounded set of favorite authors and Google Books-derived subjects.
3. Refresh QMD documents and embeddings only when public catalog metadata changes.
4. Build separate queries for `likely_to_love`, `easy_to_continue`, and `broaden_your_world`.
5. Generate candidates for each algorithm outside the web request.
6. Exclude imported books and books marked `already_read`, `not_for_me`, or `want_to_read`.
7. Compute final score: relevance 45%, reading-pattern fit 20%, current-goal fit 15%, novelty 10%, diversity 10%.
8. Penalize incomplete metadata and limit repeated authors.
9. Prevent a book from occupying two reader-facing categories in one algorithm, then mark the session completed.

Pending and processing sessions show a polling page, completed sessions expose recommendations, and failed sessions retain only a reader-safe error message. A retried job never duplicates completed recommendations. Development uses the same durable Solid Queue adapter as production, backed by a separate SQLite database.

The explanation generator uses only stored facts: shared categories, page counts, and the inferred preference snapshot. Internal scores never become reader-facing prose.

## QMD documents

`QmdBookDocumentWriter` emits only books explicitly marked `recommendable`. Imported reading-history books default to false and never enter the QMD corpus. The writer uses a controlled filename based on ISBN or database ID and never accepts a path from the upload. Each concise Markdown file contains YAML metadata, one H1, and one short description so one book remains one primary search unit.

Vector Only calls `qmd vsearch`. BM25 + Vector calls `qmd search` and `qmd vsearch` independently and fuses their ranks in Rails with reciprocal rank fusion. QMD Hybrid calls `qmd query`, preserving QMD's query expansion, fusion, and reranking stages. Every CLI call uses an argument array, an allowlisted command and collection, a bounded result count, and a timeout.

## Metadata and privacy

Book metadata enrichment is an explicit background job. It sends only ISBN, caches responses for 30 days, uses timeouts, and never blocks a successful history import. The CSV itself is read from the request tempfile and not attached or copied into storage.

Catalog discovery is a separate consented boundary. It sends at most five author names and ten subjects derived from public Google Books responses. Results are paged in batches of 20; when those signals are exhausted, a reader-independent set of public seed queries broadens the corpus across literature, SF, science, education, history, and adjacent fields. Discovery stops when the recommendable public catalog reaches 1,000 books; `BOOKTRAIL_CATALOG_TARGET` can lower that bound for development. It never sends ratings, reviews, comments, tags, profile summaries, title lists, or the CSV. Query text is not persisted: `CatalogDiscoveryQuery` stores only a page-specific SHA-256 digest, fetch time, and result count for replay guards (30 days after success, one hour after failure). Public volume metadata becomes a recommendable `Book`; the user's read/unread relationship remains private in `ReadingRecord`. Requests are throttled and retry HTTP 429 responses with a bounded delay.

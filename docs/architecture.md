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

1. Build separate queries for `likely_to_love`, `easy_to_continue`, and `broaden_your_world`.
2. Generate candidates for each algorithm.
3. Exclude imported books and books marked `already_read`, `not_for_me`, or `want_to_read`.
4. Compute final score: relevance 45%, reading-pattern fit 20%, current-goal fit 15%, novelty 10%, diversity 10%.
5. Penalize incomplete metadata and limit repeated authors.
6. Prevent a book from occupying two reader-facing categories in one algorithm.

The explanation generator uses only stored facts: shared categories, page counts, and the inferred preference snapshot. Internal scores never become reader-facing prose.

## QMD documents

`QmdBookDocumentWriter` emits only books explicitly marked `recommendable`. Imported reading-history books default to false and never enter the QMD corpus. The writer uses a controlled filename based on ISBN or database ID and never accepts a path from the upload. Each concise Markdown file contains YAML metadata, one H1, and one short description so one book remains one primary search unit.

Vector Only calls `qmd vsearch`. BM25 + Vector calls `qmd search` and `qmd vsearch` independently and fuses their ranks in Rails with reciprocal rank fusion. QMD Hybrid calls `qmd query`, preserving QMD's query expansion, fusion, and reranking stages. Every CLI call uses an argument array, an allowlisted command and collection, a bounded result count, and a timeout.

## Metadata and privacy

Book metadata enrichment is an explicit background job. It sends only ISBN, caches responses for 30 days, uses timeouts, and never blocks a successful history import. The CSV itself is read from the request tempfile and not attached or copied into storage.

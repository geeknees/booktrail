# Booktrail

## One Book Leads to Another

[Japanese README](README.ja.md)

> **OpenAI Build Week — Join a global week of building with Codex.**

Booktrail is an education-category web application created for the [OpenAI Build Week Challenge](https://openai.com/build-week/). It turns a Booklog reading-history export from a record of the past into a map for what to read next.

> The best recommendation is not merely the most similar book.
>
> It is the book that helps the reader keep reading.

Booktrail compares Vector Only, BM25 + Vector, and QMD Hybrid + Reranker for the same reader and asks:

> Which recommendation method understands this reader best?

## The problem

Most recommendation systems optimize for clicks, sales, or similarity. Readers need something more practical: a next book that matches their interests, fits how they actually finish books, and supports what they want from reading right now.

Booktrail combines private reading-history evidence with an explicit reading goal and produces three complementary paths:

- **Likely to Love** — close to highly rated books in theme, tone, authorship, or narrative structure
- **Easy to Continue** — close to books the reader tends to finish in length, complexity, genre, and voice
- **Broaden Your World** — connected to existing interests while introducing a different field, era, region, author, or viewpoint

## MVP capabilities

- Import Booklog CSV files up to 5 MB in UTF-8, UTF-8 with BOM, or Windows-31J
- Support ISBN-10/13 validation, Japanese and English headers, blank rows, duplicates, partial row errors, and Booklog's headerless 17-column export
- Enrich ISBN metadata asynchronously through openBD first and Google Books as a fallback, with 30-day caching
- Build a weighted reading profile from ratings, reading status, authors, genres, tags, page counts, and recency
- Select one of four current reading goals and receive three recommendation types
- Compare three real retrieval pipelines and inspect developer score details
- Expand a consented public recommendation catalog to 1,000 books with minimized Google Books queries
- Save want-to-read, maybe-later, not-for-me, and already-read feedback
- Exclude read books, reduce author and series concentration, prevent cross-category duplicates, and rerank for relevance, completion fit, goal fit, novelty, and diversity
- Run without QMD through a deterministic local Fallback mode
- Switch the UI, profile summaries, recommendation explanations, and QMD query intent between Japanese and English
- Delete private reading history and all derived recommendation data

## Built with Codex and GPT-5.6

This project was developed interactively with **Codex using GPT-5.6** during OpenAI Build Week. Codex was not used as a one-shot code generator. It acted as an engineering partner across repository discovery, architecture, implementation, debugging, evaluation, privacy review, documentation, and Git handoff.

### How Codex was used

| Workstream | Concrete use in Booktrail | Evidence produced |
|---|---|---|
| Product-to-code translation | Converted a detailed Japanese product brief into a Rails monolith with a complete CSV-to-feedback vertical slice | `6b4b9eb` built the MVP across models, controllers, services, views, migrations, fixtures, and tests |
| Real-data debugging | Reproduced failures against a private Booklog export of roughly 1,100 records, reported only aggregate diagnostics, and added support for headerless 17-column Windows-31J exports | `469b826` added importer compatibility and regression tests without committing the private CSV |
| Recommendation architecture | Replaced proxy scoring with real `qmd vsearch`, `qmd search`, RRF fusion, and `qmd query --explain`; kept a deterministic fallback for unavailable models | `fd804c1` added the QMD runner, query builder, three candidate paths, score evidence, and tests |
| Background execution | Traced the web request and moved expensive generation into durable Solid Queue jobs with visible pending, processing, completed, and failed states | `1b07905` added queued generation and retry-safe tests |
| Privacy-aware catalog discovery | Designed a consent boundary that sends only selected author names and public derived subjects, stores query digests rather than query text, and never sends ratings, reviews, tags, title lists, profile summaries, or raw CSV | `1cda5c9` added Google Books discovery, caching, throttling, QMD refresh, and privacy documentation |
| API failure investigation | Used direct, minimized API probes to discover that quoted Japanese `inauthor:` syntax returned zero results while the supported unquoted form worked; versioned the cache key to invalidate the failed search shape | `b1ccdf8` records the fix and test update |
| Evidence-driven scaling | Measured the real candidate bottleneck, corrected Google Books pagination from an assumed 40 to the observed 20 results per page, added reader-independent public seed fields, and grew the catalog from 30 to exactly 1,000 books | `6dde1a1` added bounded pagination, resume-safe page caching, public seed queries, docs, and tests |
| Recommendation evaluation | Re-indexed all 1,000 books locally, regenerated recommendations from the imported history, and checked category completeness, read-book exclusion, duplicates, backend provenance, and cross-algorithm overlap | The verified session produced 9 recommendations, 0 read-book overlaps, 0 duplicates, and only 1 shared book between Vector Only and QMD Hybrid |
| Internationalization | Traced locale state through the request, demo user, Solid Queue job, persisted explanations, profile generation, and QMD query construction | `177f314` added Japanese/English localization with integration and service tests |
| Quality and security gates | Worked test-first on behavioral changes, ran Minitest, RuboCop, Brakeman, Zeitwerk, and local HTTP verification, reviewed diffs from perfectionist and pragmatic perspectives, and ran a privacy scan before each commit | Current baseline: 42 tests, 181 assertions, 0 failures, 0 RuboCop offenses, 0 Brakeman warnings |

### How GPT-5.6 contributed

GPT-5.6 was used for the long-horizon reasoning behind the work rather than as an application runtime dependency:

- Maintained the product, privacy, Rails, QMD, testing, and demo constraints across many implementation iterations
- Turned observed failures into testable hypotheses, including CSV format mismatches, missing catalog coverage, Google Books rate limits, Japanese query syntax, pagination behavior, and worker environment differences
- Reasoned across controllers, jobs, services, SQLite data, QMD documents, CLI processes, and user-facing explanations instead of optimizing one isolated file
- Proposed small reversible patches, wrote regression tests first, executed the application and tools, inspected real outputs, and revised the implementation when evidence contradicted the initial model
- Preserved a clear human decision boundary: the builder chose product intent, approved external metadata queries, corrected local workflow assumptions, and controlled privacy and commit policy; Codex implemented and verified those decisions

This workflow follows the Codex pattern of giving the agent a goal, context, constraints, and a concrete definition of done, then requiring tests and review rather than accepting generated code without evidence. See the official [Codex best practices](https://learn.chatgpt.com/guides/best-practices.md) and [GPT-5.6 announcement](https://openai.com/index/gpt-5-6/).

### What does not use GPT-5.6 at runtime

Booktrail does **not** send reading profiles to an OpenAI API. Runtime recommendation uses local QMD models—Qwen3 Embedding, Qwen3 Reranker, and QMD query expansion—or the deterministic SQLite Fallback. Codex and GPT-5.6 were the development environment; they are not a hidden recommendation service.

## Architecture

Booktrail is a Rails monolith with explicit boundaries only around volatile external systems.

```text
Booklog CSV → BooklogCsvImporter → Book / ReadingRecord
                                  └→ BookMetadataJob → openBD → Google Books
ReadingRecord → ReadingProfileGenerator → ReadingProfile
ReadingProfile + Goal → RecommendationGenerationJob (Solid Queue)
                         ├→ GoogleBooksCatalogDiscovery → public candidates
                         │                              └→ QMD refresh + embedding
                         ├→ Vector Only → qmd vsearch
                         ├→ BM25 + Vector → qmd search + vsearch → RRF
                         └→ QMD Hybrid → qmd query
                                            ├→ query expansion
                                            ├→ candidate fusion
                                            └→ reranker
                                  └→ per-pipeline Fallback on failure
                ↓
       RecommendationEngine
      relevance 45% + completion fit 20% + goal fit 15%
      + novelty 10% + diversity 10%
                ↓
 RecommendationSession / Recommendation / Feedback
```

In QMD, `Document = one book` and `Query = reader profile + current goal + recommendation intent`. Likely to Love, Easy to Continue, and Broaden Your World are searched separately before read/rejected exclusions and diversity constraints are applied.

Only the operator catalog and public Google Books metadata are indexed into QMD. Private imported reading-history books are never indexed as recommendation documents. Candidate providers share the `RecommendationCandidateProvider` contract so collaborative filtering can be added later. See [docs/architecture.md](docs/architecture.md) for details.

## Requirements

- Ruby 3.4 or newer; development verified with Ruby 4.0.5
- Rails 8.1
- SQLite 3
- Node.js 22 or newer when using QMD
- `@tobilu/qmd` when using QMD

## Setup

```bash
git clone <repository-url>
cd booktrail
bin/setup
bin/rails db:seed
bin/dev
```

Open `http://localhost:3000`. The MVP intentionally uses one demo user without authentication. `bin/dev` runs Puma and a Solid Queue worker in the same process. The queue is persisted in `storage/development_queue.sqlite3`.

### Language switching

Use the header selector to switch between Japanese and English. The selection is stored in the demo user's `locale` and controls the UI, subsequently generated profile summary, recommendation explanations, and QMD query intent. Book titles, authors, categories, and other CSV or external metadata remain in their source language.

Explanations are persisted in the language active when a recommendation session is created. Switching the UI does not rewrite an existing session; create a new session after switching to generate explanations in the other language.

## Demo flow

1. Run `bin/rails db:seed` to create the initial 30-book catalog.
2. Upload [sample/booklog_sample.csv](sample/booklog_sample.csv) at `/imports/new`; it contains 22 synthetic, primarily Japanese records.
3. Review the import result and reading profile.
4. Choose the current reading goal. The generation page refreshes every three seconds.
5. Review the three reader-facing recommendations.
6. Submit feedback, compare all algorithms, and open score details.

The expected CSV headers are `ISBN, title, author, rating, reading status, category, tags, registration date, completion date`; Japanese header variants are supported. Title is required and ISBN is optional. Re-importing the same user/book updates or skips the existing record.

Booklog's headerless 17-column Windows-31J format is also supported. Its product-ID column may contain an ISBN-10 for print books or a non-ISBN identifier for ebooks. Booktrail uses it only when it is a valid ISBN and still imports ebooks without an ISBN by title and author.

## QMD integration

QMD remains a CLI boundary inside the Rails monolith. Rails calls `Open3.capture3` with fixed argument arrays, separates JSON standard output from progress on standard error, allowlists commands and collection names, and enforces timeouts. Missing binaries, model errors, malformed JSON, and timeouts fall back safely.

The three modes are not renamed versions of one proxy implementation:

- **Vector Only** calls `qmd vsearch`.
- **BM25 + Vector** calls `qmd search` and `qmd vsearch` independently and fuses their ranks in Rails with reciprocal rank fusion.
- **QMD Hybrid + Reranker** calls `qmd query --explain` and preserves query expansion, fusion, and reranking evidence.

Original ranks and available component scores are stored before the final reading-pattern, goal, novelty, and diversity rerank.

### Install and index

```bash
npm install -g @tobilu/qmd
export QMD_EMBED_MODEL="hf:Qwen/Qwen3-Embedding-0.6B-GGUF/Qwen3-Embedding-0.6B-Q8_0.gguf"
bin/rails qmd:documents
qmd init
qmd collection add tmp/qmd/books --name booktrail
qmd update
qmd embed
BOOKTRAIL_QMD=1 bin/dev
```

To run the web process and worker separately:

```bash
BOOKTRAIL_QMD=1 bin/jobs start
```

Google Books catalog discovery is enabled by default and pages until the public recommendable catalog reaches 1,000 books. If author and public-subject signals are insufficient, reader-independent public seed fields—literature, SF, science, education, history, and adjacent areas—complete the candidate corpus. Initial API requests and QMD embedding can take time; successful pages are cached for 30 days.

Shared IPs and unauthenticated requests may receive HTTP 429, so a restricted `GOOGLE_BOOKS_API_KEY` is recommended. Keep the key only in the environment. `BOOKTRAIL_CATALOG_TARGET` can lower the development target from 1,000. Disable external discovery with:

```bash
BOOKTRAIL_CATALOG_DISCOVERY=0 BOOKTRAIL_QMD=1 bin/dev
```

The project-local `.qmd/` index and generated Markdown documents are ignored by Git. Rebuild documents and embeddings after book metadata changes. Changing the embedding model requires a forced rebuild:

```bash
qmd embed -f
```

| Purpose | Model | Approximate size |
|---|---|---:|
| Embedding | Qwen3-Embedding-0.6B Q8 | 640 MB |
| Reranker | Qwen3-Reranker-0.6B Q8 | 640 MB |
| Query expansion | QMD default 1.7B Q4 | 1.1 GB |

Allow roughly 2.4 GB plus index storage. Models download on first `qmd embed` or `qmd query` and are cached by default in `~/.cache/qmd/models/`. The project index is `.qmd/index.sqlite`; global QMD use defaults to `~/.cache/qmd/index.sqlite`. `XDG_CACHE_HOME` can relocate the cache. Refer to [tobi/qmd](https://github.com/tobi/qmd) for current QMD requirements and CLI details.

### Fallback mode

Fallback is the default when `BOOKTRAIL_QMD` is unset. Recommendations created from `/recommendation_sessions/new` still use the real imported profile and recommendable catalog, but score keyword overlap, category connection, page fit, goal fit, and novelty deterministically in SQLite. It is not a fixture mock.

To create recommendations with QMD from the UI, stop the server and restart it before creating a new session:

```bash
BOOKTRAIL_QMD=1 bin/dev
```

Existing sessions are not recalculated. If QMD is missing, times out, or returns malformed output, only that retrieval operation falls back automatically. Open **Score details** from the algorithm comparison page and inspect `Backend`: `qmd` means the real QMD pipeline ran, while `fallback` means the deterministic local path ran.

## Tests and quality checks

```bash
bin/rails test
bin/rubocop
bundle exec brakeman --no-pager
```

The suite covers CSV boundaries, ISBN handling, profile weights, read and feedback exclusions, category uniqueness, all three recommendation modes, QMD failure fallback, file restrictions, locale persistence, background-job locale propagation, and the browser-level vertical flow.

## External data sources

1. [openBD API](https://openbd.jp/) — primary ISBN metadata source
2. [Google Books API](https://developers.google.com/books/docs/v1/using) — description, category, page-count fallback and public unread-candidate discovery
3. User-provided CSV — retained only as parsed application records when APIs cannot fill metadata

ISBN enrichment sends only the ISBN. Consented candidate discovery searches up to five profile authors and up to ten subjects derived from public Google Books results. It requests 20 results per page, uses reader-independent seed queries only when needed, and stops at the configured catalog target.

It does not send ratings, reviews, comments, Booklog tags, profile summaries, title lists, or raw CSV. Query text is not stored; the database retains only a page-specific SHA-256 digest, fetch time, and result count. Successful pages are not repeated for 30 days and failed pages for one hour. Requests are throttled and HTTP 429 retries are bounded. Booktrail does not scrape Booklog.

## Privacy

- Use only history uploaded by the reader; never retain the original upload
- Separate private reading history from the public recommendation catalog; never index private history books into QMD
- Do not use review text or comments for MVP recommendations
- Send only ISBN for ISBN enrichment
- Send selected authors and public derived subjects only after consented catalog discovery is enabled
- Use the same public seed fields for every reader; never derive them from private history
- Never send ratings, reviews, comments, tags, title lists, profile summaries, or raw CSV during discovery
- Run embedding, query expansion, and reranking locally so the reading profile does not leave the machine for an external LLM
- Provide deletion of history, profile, recommendations, and feedback
- Require separate explicit consent before future anonymous aggregation or collaborative filtering

## Current limitations

- No authentication; the MVP uses one demo user
- Metadata enrichment needs a running job worker, but CSV metadata remains usable without it
- Fallback vector and BM25 values are lightweight proxy scores, not QMD model evaluations
- Series detection is conservative because ISBN metadata does not reliably expose series identity
- QMD `--explain` fields vary by CLI version; unavailable values appear as `—`
- Local model startup, first download, and CPU inference can make QMD generation slow
- Background generation exposes lifecycle states rather than a precise percentage
- Candidate coverage depends on Google Books quality and quota; failures continue with the existing catalog
- Cover images depend on external hosts; missing covers use a local placeholder
- UI locale and preferred book language are not yet separate preferences

## Future collaborative filtering

After enough users explicitly consent to pooled data, a `CollaborativeFilteringCandidateProvider` can be added behind the existing provider contract. Candidate signals would include co-occurrence count, cosine similarity, lift, Bayesian smoothing, popularity correction, and a minimum co-occurrence threshold. Booktrail intentionally does not simulate collaborative filtering before that data exists.

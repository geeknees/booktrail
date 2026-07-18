# AGENTS.md

- Booktrail is a Rails monolith. Follow Rails conventions, use Minitest, and work test-first for behavioral changes.
- Ruby and Node mise shims are already on `PATH`. If a tool cannot be resolved, use `mise exec -- <command>`.
- Never commit a user's raw Booklog export or reading history. Fixtures and samples must be synthetic or anonymized.

## Before committing

1. Stage only files belonging to the task.
2. Run `ruby ~/.claude/skills/privacy-check/scripts/privacy_check.rb` against the staged diff.
3. Commit only after every finding is confirmed harmless. Stop if any finding is real or uncertain.
4. Report only the pass/fail conclusion; do not expose privacy-check matches or internal patterns.

Before publishing, also run the privacy check with `--full`.

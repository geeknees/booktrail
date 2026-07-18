# Gotchas

## Booklog CSV exports

- 実際のBooklogエクスポートには、ヘッダーなし・17列・Windows-31Jの形式がある。ヘッダー付きの想定fixtureだけでImporterを設計しない。
- ヘッダーなし形式の2列目はISBN-10専用ではなく商品IDであり、電子書籍ではASINが入る。有効なISBNだけを採用し、ASINはISBN不正エラーにせずタイトル・著者へフォールバックする。
- CSV連携は匿名化fixtureに加えて、ユーザー提供の実ファイル全件をロールバック可能な環境で検証する。

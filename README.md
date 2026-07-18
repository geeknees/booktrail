# Booktrail

## One Book Leads to Another

Booktrailは、Booklog（ブクログ）の読書履歴を「過去の記録」から「次に読む本へつながる地図」へ変える教育カテゴリ向けWebアプリです。

> The best recommendation is not merely the most similar book.
>
> It is the book that helps the reader keep reading.

同じ読者に対する Vector Only、BM25 + Vector、QMD Hybrid + Reranker の結果を比較し、どの方式がその読者をよく理解するか検証できます。

## MVPでできること

- Booklog形式CSVの取込（UTF-8/BOM/Windows-31J、最大5MB）
- ISBN-10/13検証、列名揺れ、空行、重複、部分エラーへの対応
- openBD優先、Google Books fallbackによる非同期書誌補完と30日キャッシュ
- 評価・読書状況を重み付けした読書プロフィール
- 4つの読書目的と3つの推薦枠
- 3方式の推薦比較、開発者向けスコア内訳
- 読みたい／あとで／合わない／既読のフィードバック
- 既読除外、著者偏重抑制、カテゴリ間重複排除、品質・多様性を含むリランキング
- QMDなしでも動く決定的なFallbackモード
- 読書履歴と派生推薦データの削除

## アーキテクチャ

Railsモノリスの中で、変わりやすい外部境界だけを分離しています。

```text
Booklog CSV → BooklogCsvImporter → Book / ReadingRecord
                                  └→ BookMetadataJob → openBD → Google Books
ReadingRecord → ReadingProfileGenerator → ReadingProfile
ReadingProfile + Goal
  ├→ Vector Only provider
  ├→ BM25 + Vector provider
  └→ QMD Hybrid provider → QMD CLI（失敗時Fallback）
                ↓
       RecommendationEngine
      関連度45% + 読了傾向20% + 目的15% + 新規性10% + 多様性10%
                ↓
 RecommendationSession / Recommendation / Feedback
```

QMDでは `Document = 1冊`、`Query = 読者プロフィール + 今回の目的 + 推薦意図` です。Likely to Love、Easy to Continue、Broaden Your Worldを別々に検索してから、既読除外と多様性制約を適用します。候補Providerの共通契約は `RecommendationCandidateProvider` にあり、将来の協調フィルタリングを差し込めます。詳細は [docs/architecture.md](docs/architecture.md) を参照してください。

## 必要環境

- Ruby 3.4以上（開発時確認: Ruby 4.0.5）
- Rails 8.1系
- SQLite 3
- Node.js 22以上（QMDを使う場合のみ）
- QMD `@tobilu/qmd`（任意）

## セットアップ

```bash
git clone <repository-url>
cd booktrail
eval "$(mise activate zsh)"
bin/setup
bin/rails db:seed
bin/dev
```

ブラウザで `http://localhost:3000` を開きます。認証を省いたMVPのため、単一のデモユーザーを使用します。

## デモ手順

1. `bin/rails db:seed` で30冊の推薦カタログを作る
2. `/imports/new` で [sample/booklog_sample.csv](sample/booklog_sample.csv) をアップロードする（日本語書籍中心・22件）
3. 取込結果と読書プロフィールを見る
4. 今回の読書目的を選び、3つの推薦を見る
5. フィードバックを送り、アルゴリズム比較とスコア詳細を開く

サンプルCSVの想定列は `ISBN, タイトル, 著者, 評価, 読書状況, カテゴリ, タグ, 登録日, 読了日` です。タイトルは必須、ISBNは任意です。実ファイルの列名揺れにも一部対応します。同一ユーザー・同一ISBN（ISBNなしはタイトル＋著者）は再取込時に更新またはスキップします。

Booklogが出力するヘッダーなし・17列・Windows-31J形式にも対応しています。この形式の2列目は紙書籍ではISBN-10、電子書籍ではASINなどの商品IDになるため、有効なISBNの場合だけ書籍識別子として使います。ISBNのない電子書籍もタイトルと著者から取り込みます。

## QMD統合

QMDは別サービスにせず、Railsから `Open3.capture2e` へ固定の引数配列を渡して呼びます。ユーザー入力をシェル文字列へ連結しません。20秒でタイムアウトし、バイナリ不在、モデルエラー、JSON不正を含む障害時はFallbackへ戻ります。

### インストールとインデックス

```bash
npm install -g @tobilu/qmd
export QMD_EMBED_MODEL="hf:Qwen/Qwen3-Embedding-0.6B-GGUF/Qwen3-Embedding-0.6B-Q8_0.gguf"
eval "$(mise activate zsh)"
bin/rails qmd:documents
qmd collection add "$(pwd)/tmp/qmd/books" --name booktrail
qmd update
qmd embed
BOOKTRAIL_QMD=1 bin/dev
```

書籍更新後は `bin/rails qmd:documents && qmd update && qmd embed` を実行します。Embeddingモデルを変えた場合、既存ベクトルに互換性がないため必ず再生成します。

```bash
qmd embed -f
```

QMDの標準構成を基本に、Embeddingのみ日本語向けQwen3へ変更します。

| 用途 | モデル | おおよその容量 |
|---|---|---:|
| Embedding | Qwen3-Embedding-0.6B Q8 | 約640MB |
| Reranker | Qwen3-Reranker-0.6B Q8 | 約640MB |
| Query expansion | QMD標準 1.7B Q4 | 約1.1GB |

合計は約2.4GBに加え、インデックス領域が必要です。モデルは初回の `qmd embed` / `qmd query` 時にダウンロードされ、既定では `~/.cache/qmd/models/`、インデックスは `~/.cache/qmd/index.sqlite` に保存されます。`XDG_CACHE_HOME` で変更できます。QMDの現行要件とCLIは [tobi/qmd](https://github.com/tobi/qmd) を参照してください。

### Fallbackモード

`BOOKTRAIL_QMD` を設定しない状態が既定です。SQLiteの書誌情報からキーワード一致、カテゴリ接点、ページ数、目的、新規性を決定的に採点するため、モデルやネットワークなしでUI開発、テスト、デモができます。Fallbackのスコアは本番のEmbedding品質を再現するものではなく、画面と評価導線を検証するためのものです。

## テストと品質確認

```bash
eval "$(mise activate zsh)"
bin/rails test
bin/rubocop
bundle exec brakeman --no-pager
```

CSV境界、ISBN、プロフィール重み、既読・フィードバック除外、カテゴリ重複、3方式、QMD Fallback、ファイル形式制限、ブラウザの縦フローをMinitestで確認します。

## 外部データソース

1. [openBD API](https://openbd.jp/) — ISBN書誌情報の第一候補
2. [Google Books API](https://developers.google.com/books) — openBDで見つからない場合
3. ユーザー提供CSV — APIで補完できない場合

API呼出しはISBNだけを送り、接続・読取とも4秒でタイムアウトします。同じISBNの結果はRails cacheへ30日保存します。Booklog全体のスクレイピングは行いません。

## プライバシー

- ユーザー本人がアップロードした履歴だけを使用し、アップロード原本は保存しません
- レビュー本文・コメントはMVPの推薦へ送りません
- 外部書誌APIへ送るのはISBNだけです
- QMDのEmbedding、Query Expansion、Rerankerはローカル実行でき、読書プロフィールを外部LLMへ送らずに済みます
- プロフィール画面から履歴、プロフィール、推薦、フィードバックを削除できます
- 将来の匿名集計や協調フィルタリングには別途明示的な同意が必要です

## 現在の制約

- 認証はなく、単一デモユーザーです
- 書誌補完はジョブ実行環境が必要です。ローカルでSolid Queueを動かさない場合もCSV情報で継続します
- FallbackのVector/BM25値は軽量な代理スコアで、QMDの実モデル評価ではありません
- シリーズ判定データがないため、MVPでは同一著者制約とカテゴリ間重複排除を優先します
- QMD CLI JSONの `--explain` 項目はバージョン差を許容し、欠落値は開発者画面で `—` と表示します
- 書影URLは外部配信元に依存します。欠落時はローカルのプレースホルダーを表示します

## 将来の協調フィルタリング

十分な同意済みユーザーデータが集まった段階で `CollaborativeFilteringCandidateProvider` を追加します。共起数、cosine similarity、lift、Bayesian smoothing、人気度補正、最低共起数を評価します。現時点ではデータがないため、見せかけの協調フィルタリングは実装していません。

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
- 同意済みの最小化クエリによるGoogle Books候補カタログ拡張
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
ReadingProfile + Goal → RecommendationGenerationJob（Solid Queue）
                         ├→ GoogleBooksCatalogDiscovery → 公開候補を追加
                         │                              └→ QMD差分更新・Embedding
                         ├→ Vector Only → qmd vsearch
                         ├→ BM25 + Vector → qmd search + vsearch → RRF
                         └→ QMD Hybrid → qmd query（Query Expansion + RRF + Reranker）
                                              └→ 障害時は各方式のFallback
                ↓
       RecommendationEngine
      関連度45% + 読了傾向20% + 目的15% + 新規性10% + 多様性10%
                ↓
 RecommendationSession / Recommendation / Feedback
```

QMDでは `Document = 1冊`、`Query = 読者プロフィール + 今回の目的 + 推薦意図` です。Likely to Love、Easy to Continue、Broaden Your Worldを別々に検索してから、既読・拒否済み候補の除外と多様性制約を適用します。QMDへ索引するのは運営側の推薦カタログと、Google Booksから取得した公開書誌だけです。ユーザーが取り込んだ非公開の読書履歴そのものは検索文書にしません。候補Providerの共通契約は `RecommendationCandidateProvider` にあり、将来の協調フィルタリングを差し込めます。詳細は [docs/architecture.md](docs/architecture.md) を参照してください。

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
bin/setup
bin/rails db:seed
bin/dev
```

ブラウザで `http://localhost:3000` を開きます。認証を省いたMVPのため、単一のデモユーザーを使用します。`bin/dev` はPumaとSolid Queueワーカーを一緒に起動し、時間のかかる推薦生成中もWebリクエストを待たせません。Queueは `storage/development_queue.sqlite3` に永続化されます。

## デモ手順

1. `bin/rails db:seed` で30冊の推薦カタログを作る
2. `/imports/new` で [sample/booklog_sample.csv](sample/booklog_sample.csv) をアップロードする（日本語書籍中心・22件）
3. 取込結果と読書プロフィールを見る
4. 今回の読書目的を選ぶ（生成中画面は3秒ごとに自動更新される）
5. 3つの推薦を見る
6. フィードバックを送り、アルゴリズム比較とスコア詳細を開く

サンプルCSVの想定列は `ISBN, タイトル, 著者, 評価, 読書状況, カテゴリ, タグ, 登録日, 読了日` です。タイトルは必須、ISBNは任意です。実ファイルの列名揺れにも一部対応します。同一ユーザー・同一ISBN（ISBNなしはタイトル＋著者）は再取込時に更新またはスキップします。

Booklogが出力するヘッダーなし・17列・Windows-31J形式にも対応しています。この形式の2列目は紙書籍ではISBN-10、電子書籍ではASINなどの商品IDになるため、有効なISBNの場合だけ書籍識別子として使います。ISBNのない電子書籍もタイトルと著者から取り込みます。

## QMD統合

QMDは別サービスにせず、Railsから `Open3.capture3` へ固定の引数配列を渡して呼びます。標準出力のJSONと標準エラーの進捗表示を分離し、ユーザー入力をシェル文字列へ連結しません。コマンドとcollection名は許可リストで検証し、各呼出しは45秒でタイムアウトします。バイナリ不在、モデルエラー、JSON不正を含む障害時はFallbackへ戻ります。

3方式は名前だけを変えた代理実装ではありません。Vector Onlyは `qmd vsearch`、BM25 + Vectorは `qmd search` と `qmd vsearch` を別々に実行してアプリ側でReciprocal Rank Fusion、QMD Hybridは `qmd query --explain` によるQuery Expansion・候補統合・Rerankerを使います。検索結果の元順位と各スコアは保存し、読了傾向、今回の目的、新規性、多様性を加えた最終リランキングを行います。

### インストールとインデックス

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

通常は `bin/dev` 内でSolid Queueも起動します。Webとワーカーを分けて確認したい場合は、別ターミナルで次を実行します。

```bash
BOOKTRAIL_QMD=1 bin/jobs start
```

Google Booksによる候補発見は既定で有効です。共有IPや無認証アクセスはHTTP 429になる場合があるため、継続利用では制限付きの `GOOGLE_BOOKS_API_KEY` を推奨します。キーは環境変数だけに置き、リポジトリへ保存しません。外部候補発見を完全に停止する場合は次のように起動します。

```bash
BOOKTRAIL_CATALOG_DISCOVERY=0 BOOKTRAIL_QMD=1 bin/dev
```

`qmd init` によりプロジェクトローカルの `.qmd/` にインデックスが作られます。このディレクトリと生成MarkdownはGit管理外です。書籍更新後は `bin/rails qmd:documents && qmd update && qmd embed` を実行します。Embeddingモデルを変えた場合、既存ベクトルに互換性がないため必ず再生成します。

```bash
qmd embed -f
```

QMDの標準構成を基本に、Embeddingのみ日本語向けQwen3へ変更します。

| 用途 | モデル | おおよその容量 |
|---|---|---:|
| Embedding | Qwen3-Embedding-0.6B Q8 | 約640MB |
| Reranker | Qwen3-Reranker-0.6B Q8 | 約640MB |
| Query expansion | QMD標準 1.7B Q4 | 約1.1GB |

合計は約2.4GBに加え、インデックス領域が必要です。モデルは初回の `qmd embed` / `qmd query` 時にダウンロードされ、既定では `~/.cache/qmd/models/` に保存されます。Booktrailのインデックスは `.qmd/index.sqlite`、グローバル運用時の既定は `~/.cache/qmd/index.sqlite` です。モデルキャッシュは `XDG_CACHE_HOME` で変更できます。QMDの現行要件とCLIは [tobi/qmd](https://github.com/tobi/qmd) を参照してください。

### Fallbackモード

`BOOKTRAIL_QMD` を設定しない状態が既定です。SQLiteの書誌情報からキーワード一致、カテゴリ接点、ページ数、目的、新規性を決定的に採点するため、モデルやネットワークなしでUI開発、テスト、デモができます。FallbackはQMDのEmbeddingやRerankerスコアを装わず、開発者画面には取得できた値だけを表示します。

## テストと品質確認

```bash
bin/rails test
bin/rubocop
bundle exec brakeman --no-pager
```

CSV境界、ISBN、プロフィール重み、既読・フィードバック除外、カテゴリ重複、3方式、QMD Fallback、ファイル形式制限、ブラウザの縦フローをMinitestで確認します。

## 外部データソース

1. [openBD API](https://openbd.jp/) — ISBN書誌情報の第一候補
2. [Google Books API](https://developers.google.com/books/docs/v1/using) — openBDで不足する説明・カテゴリ・ページ数の補完、および未読候補の公開書誌検索
3. ユーザー提供CSV — APIで補完できない場合

ISBN書誌補完ではISBNだけを送信します。候補発見では、ユーザーが同意した場合に限り、プロフィール上位3著者を `inauthor:` 検索し、その公開結果から得た最大2カテゴリを `subject:` 検索します。評価、レビュー、コメント、Booklogタグ、プロフィール要約、書名一覧、生CSVは送信しません。検索文字列自体はDBへ保存せず、SHA-256ダイジェストと取得日時だけを保持します。成功した検索は30日、失敗した検索は1時間再送せず、HTTP 429を繰り返し発生させません。Google Booksの公開検索は最大40件を返せますが、Booktrailは1検索20件に制限し、検索間隔とHTTP 429の再試行を制御します。Booklog全体のスクレイピングは行いません。

## プライバシー

- ユーザー本人がアップロードした履歴だけを使用し、アップロード原本は保存しません
- ユーザーの読書履歴と運営側の推薦カタログをDB上で分離し、履歴の書籍はQMDへ索引しません
- レビュー本文・コメントはMVPの推薦へ送りません
- ISBN書誌補完で外部APIへ送るのはISBNだけです
- 候補発見を有効にした場合だけ、上位3著者名と公開書誌から派生した最大2カテゴリをGoogle Booksへ送ります
- 候補発見には評価、レビュー、コメント、タグ、書名一覧、生CSVを送りません
- QMDのEmbedding、Query Expansion、Rerankerはローカル実行でき、読書プロフィールを外部LLMへ送らずに済みます
- プロフィール画面から履歴、プロフィール、推薦、フィードバックを削除できます
- 将来の匿名集計や協調フィルタリングには別途明示的な同意が必要です

## 現在の制約

- 認証はなく、単一デモユーザーです
- 書誌補完はジョブ実行環境が必要です。ローカルでSolid Queueを動かさない場合もCSV情報で継続します
- FallbackのVector/BM25値は軽量な代理スコアで、QMDの実モデル評価ではありません
- ISBNからシリーズ情報を安定取得できないため、タイトルの巻数表記による保守的なシリーズ判定です
- QMD CLI JSONの `--explain` 項目はバージョン差を許容し、欠落値は開発者画面で `—` と表示します
- QMDモードはローカルモデルを同期実行するため、初回ダウンロード時やCPU環境では推薦生成に時間がかかります
- 推薦はSolid Queueで非同期生成しますが、MVPでは進捗率ではなく pending／processing／completed／failed の状態表示です
- Google Booksの検索品質とAPI割当に依存します。障害時は既存カタログだけで推薦を続行します
- 書影URLは外部配信元に依存します。欠落時はローカルのプレースホルダーを表示します

## 将来の協調フィルタリング

十分な同意済みユーザーデータが集まった段階で `CollaborativeFilteringCandidateProvider` を追加します。共起数、cosine similarity、lift、Bayesian smoothing、人気度補正、最低共起数を評価します。現時点ではデータがないため、見せかけの協調フィルタリングは実装していません。

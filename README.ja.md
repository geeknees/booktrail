# Booktrail

## One Book Leads to Another

[English README](README.md)

> **OpenAI Build Week — Join a global week of building with Codex.**

Booktrailは、[OpenAI Build Week Challenge](https://openai.com/build-week/)のために制作した教育カテゴリ向けWebアプリです。Booklog（ブクログ）の読書履歴を「過去の記録」から「次に読む本へつながる地図」へ変えます。

> The best recommendation is not merely the most similar book.
>
> It is the book that helps the reader keep reading.

同じ読者に対する Vector Only、BM25 + Vector、QMD Hybrid + Reranker の結果を比較し、次の問いを検証できます。

> Which recommendation method understands this reader best?

## 解決する問題

多くの推薦システムはクリック、販売、類似度を最適化します。しかし読者に必要なのは、興味に合うだけでなく、実際の読了傾向と今の読書目的に合い、次の読書行動につながる一冊です。

Booktrailは、個人の読書履歴と今回の読書目的を組み合わせ、3つの異なる道を示します。

- **きっと好き / Likely to Love** — 高評価本とテーマ、雰囲気、著者性、物語構造が近い本
- **読み切れそう / Easy to Continue** — 読了本と長さ、複雑さ、ジャンル、語り口が近い本
- **世界を広げる / Broaden Your World** — 主な興味と接点を持ちながら、分野、時代、地域、著者、観点が異なる本

## MVPでできること

- Booklog形式CSVの取込（UTF-8、BOM付きUTF-8、Windows-31J、最大5MB）
- ISBN-10/13検証、日本語・英語列名、空行、重複、部分エラー、ヘッダーなし17列形式への対応
- openBD優先、Google Books fallbackによる非同期書誌補完と30日キャッシュ
- 評価、読書状況、著者、ジャンル、タグ、ページ数、最近の関心を重み付けした読書プロフィール
- 4つの読書目的と3つの推薦枠
- 3方式の実検索パイプライン比較と開発者向けスコア内訳
- 同意済みの最小化クエリによる1,000冊の公開候補カタログ
- 読みたい、あとで、合わない、既読のフィードバック
- 既読除外、著者・シリーズ偏重抑制、カテゴリ間重複排除、品質・多様性を含むリランキング
- QMDなしでも動く決定的Fallback
- 日本語・英語のUI、プロフィール要約、推薦理由、QMD検索意図
- 読書履歴と派生推薦データの削除

## CodexとGPT-5.6による開発

このプロジェクトはOpenAI Build Week期間中に、**GPT-5.6を使用するCodex**と対話しながら開発しました。Codexは一度だけコードを生成する道具ではなく、リポジトリ調査、設計、実装、デバッグ、実データ評価、プライバシーレビュー、ドキュメント、Git引き渡しまでを担うエンジニアリングパートナーとして使用しました。

### Codexをどのように使ったか

| 作業領域 | Booktrailでの具体的な活用 | 残った証拠 |
|---|---|---|
| 要件から動くプロダクトへ | 日本語の詳細なプロダクト要件を、CSV取込からフィードバックまで動くRailsモノリスへ変換 | `6b4b9eb` でモデル、Controller、Service、View、Migration、Fixture、Testを実装 |
| 実データデバッグ | 約1,100件の非公開Booklogデータで不具合を再現し、集計値だけを報告。ヘッダーなし17列・Windows-31J形式へ対応 | `469b826` で取込対応と回帰テストを追加し、生CSVは未コミット |
| 推薦アーキテクチャ | 代理スコアを、実際の `qmd vsearch`、`qmd search`、RRF、`qmd query --explain`へ置換。モデルが使えない環境向けFallbackは維持 | `fd804c1` でQMD runner、query builder、3方式、スコア証拠、テストを追加 |
| 非同期処理 | Webリクエストを追跡し、重い推薦生成をSolid Queueへ移動。pending、processing、completed、failedを画面化 | `1b07905` でジョブ化と再実行安全性テストを追加 |
| プライバシー境界 | 外部へ送る情報を選択著者名と公開結果由来カテゴリへ限定。検索文ではなくダイジェストを保存し、評価、レビュー、タグ、書名一覧、要約、生CSVは送らない設計 | `1cda5c9` で候補発見、キャッシュ、throttle、QMD更新、説明文書を追加 |
| API不具合の原因特定 | 最小化したAPIプローブで、引用符付き日本語 `inauthor:` が0件、引用符なし形式が取得成功することを確認。失敗形のキャッシュもversion更新 | `b1ccdf8` に修正とテストを記録 |
| 証拠ベースの1000冊化 | 候補不足を測定し、Google Booksの実レスポンスが1ページ20件であることを確認。ページングと全ユーザー共通の公開分野を追加し、30冊から正確に1,000冊へ拡張 | `6dde1a1` で上限付きページング、再開可能キャッシュ、公開seed、文書、テストを追加 |
| 推薦評価 | 1,000冊をローカルで再Embeddingし、実履歴から再推薦。カテゴリ充足、既読除外、重複、backend、方式間重複を検証 | 9推薦、既読混入0、重複0、Vector OnlyとQMD Hybridの共通本1冊を確認 |
| 多言語化 | request、デモユーザー、Solid Queue、永続化する推薦理由、プロフィール、QMD queryまでlocaleの流れを追跡 | `177f314` で日英対応と統合・Serviceテストを追加 |
| 品質・セキュリティ | 挙動変更はtest-first。Minitest、RuboCop、Brakeman、Zeitwerk、ローカルHTTP確認、二視点レビュー、各commit前privacy scanを実行 | 現在42 tests、181 assertions、失敗0、RuboCop違反0、Brakeman警告0 |

### GPT-5.6をどのように使ったか

GPT-5.6はアプリの実行時依存ではなく、長い開発サイクルを通した推論に使用しました。

- プロダクト、プライバシー、Rails、QMD、テスト、デモ要件を複数iterationにわたり維持
- CSV形式差異、候補不足、Google Books rate limit、日本語query構文、pagination、worker環境差を、観測結果から検証可能な仮説へ変換
- 単一ファイルだけでなく、Controller、Job、Service、SQLite、QMD document、CLI process、推薦理由を一つのdata flowとして分析
- 小さく戻せるpatchを提案し、先に回帰testを書き、アプリとtoolを実行し、初期仮説と証拠が食い違えば実装を修正
- 人間との境界を維持。人間がプロダクト意図、外部送信への同意、ローカル運用、プライバシーとcommit方針を決め、Codexが実装と検証を担当

この進め方は、Codexへgoal、context、constraints、done conditionを渡し、生成結果だけで止めずtestとreviewまで要求する公式best practiceに沿っています。詳しくは[Codex best practices](https://learn.chatgpt.com/guides/best-practices.md)と[GPT-5.6 announcement](https://openai.com/index/gpt-5-6/)を参照してください。

### 実行時にGPT-5.6を使わない理由

Booktrailは読書プロフィールをOpenAI APIへ送りません。実行時推薦はQMDのローカルモデル（Qwen3 Embedding、Qwen3 Reranker、QMD Query Expansion）またはSQLiteの決定的Fallbackで動きます。CodexとGPT-5.6は開発環境であり、隠れた推薦APIではありません。

## アーキテクチャ

Railsモノリスの中で、変わりやすい外部境界だけを分離しています。

```text
Booklog CSV → BooklogCsvImporter → Book / ReadingRecord
                                  └→ BookMetadataJob → openBD → Google Books
ReadingRecord → ReadingProfileGenerator → ReadingProfile
ReadingProfile + Goal → RecommendationGenerationJob（Solid Queue）
                         ├→ GoogleBooksCatalogDiscovery → 公開候補
                         │                              └→ QMD更新・Embedding
                         ├→ Vector Only → qmd vsearch
                         ├→ BM25 + Vector → qmd search + vsearch → RRF
                         └→ QMD Hybrid → qmd query
                                            ├→ Query Expansion
                                            ├→ Candidate Fusion
                                            └→ Reranker
                                  └→ 障害時は方式ごとにFallback
                ↓
       RecommendationEngine
      関連度45% + 読了傾向20% + 目的15% + 新規性10% + 多様性10%
                ↓
 RecommendationSession / Recommendation / Feedback
```

QMDでは `Document = 1冊`、`Query = 読者プロフィール + 今回の目的 + 推薦意図` です。3つの推薦意図を別々に検索してから、既読・拒否済み候補の除外と多様性制約を適用します。

QMDへ索引するのは運営側カタログとGoogle Booksの公開書誌だけです。ユーザーが取り込んだ非公開履歴の本は推薦文書として索引しません。候補Providerの共通契約は `RecommendationCandidateProvider` にあり、将来の協調フィルタリングを追加できます。詳細は[docs/architecture.md](docs/architecture.md)を参照してください。

## 必要環境

- Ruby 3.4以上（開発時確認: Ruby 4.0.5）
- Rails 8.1系
- SQLite 3
- Node.js 22以上（QMDを使う場合）
- QMD `@tobilu/qmd`（QMDを使う場合）

## セットアップ

```bash
git clone <repository-url>
cd booktrail
bin/setup
bin/rails db:seed
bin/dev
```

`http://localhost:3000` を開きます。MVPでは認証を省き、単一デモユーザーを使います。`bin/dev` はPumaとSolid Queue workerを同じprocessで起動し、queueは `storage/development_queue.sqlite3` に永続化されます。

### 言語切替

Headerの言語選択で日本語と英語を切り替えられます。選択はデモユーザーの `locale` に保存され、UI、その後生成するプロフィール要約、推薦理由、QMD検索意図に反映されます。書名、著者、カテゴリなどCSV・外部書誌由来の値は原文を保持します。

推薦理由はsession作成時の言語で保存されます。既存sessionは言語切替だけでは再翻訳されないため、別言語の理由が必要なら切替後に新しいsessionを作成してください。

## デモ手順

1. `bin/rails db:seed` で最初の30冊を作成
2. `/imports/new` で [sample/booklog_sample.csv](sample/booklog_sample.csv) をupload（日本語書籍中心・合成22件）
3. 取込結果と読書プロフィールを確認
4. 今回の読書目的を選択。生成画面は3秒ごとに更新
5. 3つの推薦を確認
6. Feedbackを送り、3方式の比較とscore詳細を確認

想定列は `ISBN, タイトル, 著者, 評価, 読書状況, カテゴリ, タグ, 登録日, 読了日` です。Titleは必須、ISBNは任意です。同じユーザー・同じ本の再取込は更新またはskipします。

Booklogのヘッダーなし17列・Windows-31J形式にも対応します。商品ID列は紙書籍ではISBN-10、電子書籍では非ISBNの場合があるため、有効なISBNだけを識別子として利用します。ISBNなし電子書籍もtitleとauthorで取り込みます。

## QMD統合

QMDは別serviceにせず、Railsから `Open3.capture3` へ固定引数配列を渡して呼びます。JSON stdoutと進捗stderrを分離し、commandとcollectionをallowlistし、timeoutを設定します。Binary不在、model error、JSON不正、timeoutは安全にFallbackします。

3方式は名前だけを変えた代理実装ではありません。

- **Vector Only**: `qmd vsearch`
- **BM25 + Vector**: `qmd search` と `qmd vsearch` を別々に実行し、RailsでRRF
- **QMD Hybrid + Reranker**: `qmd query --explain` でQuery Expansion、Fusion、Reranking

元順位と取得できたcomponent scoreを保存し、読了傾向、目的、新規性、多様性で最終rerankします。

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

Webとworkerを分ける場合:

```bash
BOOKTRAIL_QMD=1 bin/jobs start
```

Google Books候補発見は既定で有効で、推薦可能な公開書誌が1,000冊になるまでpage取得します。著者・公開カテゴリで不足する場合は、文学、SF、科学、教育、歴史など全ユーザー共通の公開分野で補います。初回API requestとEmbeddingには時間がかかります。成功pageは30日cacheします。

共有IPや無認証requestはHTTP 429になる場合があるため、制限付き `GOOGLE_BOOKS_API_KEY` を推奨します。Keyは環境変数だけに置きます。`BOOKTRAIL_CATALOG_TARGET` で開発時の上限を下げられます。外部候補発見を止める場合:

```bash
BOOKTRAIL_CATALOG_DISCOVERY=0 BOOKTRAIL_QMD=1 bin/dev
```

Project localの `.qmd/` と生成MarkdownはGit管理外です。書誌更新後はdocumentとEmbeddingを再生成します。Embedding modelを変更した場合:

```bash
qmd embed -f
```

| 用途 | モデル | おおよその容量 |
|---|---|---:|
| Embedding | Qwen3-Embedding-0.6B Q8 | 640 MB |
| Reranker | Qwen3-Reranker-0.6B Q8 | 640 MB |
| Query expansion | QMD標準 1.7B Q4 | 1.1 GB |

合計約2.4 GBにindex領域が必要です。初回 `qmd embed` / `qmd query` でdownloadされ、既定cacheは `~/.cache/qmd/models/`、project indexは `.qmd/index.sqlite` です。`XDG_CACHE_HOME` でcache先を変更できます。QMD要件は[tobi/qmd](https://github.com/tobi/qmd)を参照してください。

### Fallbackモード

`BOOKTRAIL_QMD` 未設定が既定です。`/recommendation_sessions/new` から作った場合も、実際の読書プロフィールと推薦カタログを使い、SQLiteでkeyword、category、page数、目的、新規性を決定的に採点します。Fixture mockではありません。

UIからQMD推薦を作る場合はserverを停止し、次で再起動してから新しいsessionを作成します。

```bash
BOOKTRAIL_QMD=1 bin/dev
```

既存sessionは再計算されません。QMDが利用不能、timeout、JSON不正の場合はその検索だけFallbackします。Algorithm比較から「Score details」を開き、`Backend` が `qmd` または `fallback` のどちらかで実経路を確認できます。

## テストと品質確認

```bash
bin/rails test
bin/rubocop
bundle exec brakeman --no-pager
```

CSV境界、ISBN、profile weight、既読・feedback除外、category重複、3方式、QMD障害Fallback、file制限、locale永続化、jobへのlocale伝播、browser相当の縦flowをMinitestで確認します。

## 外部データソース

1. [openBD API](https://openbd.jp/) — ISBN書誌の第一候補
2. [Google Books API](https://developers.google.com/books/docs/v1/using) — 説明、カテゴリ、ページ数のfallbackと公開未読候補
3. ユーザー提供CSV — APIで補完できない場合

ISBN補完で送るのはISBNだけです。同意済み候補発見ではプロフィール上位5著者と、公開Google Books結果から派生した最大10カテゴリを検索します。1page 20件で、必要な場合だけ全ユーザー共通seedを使い、設定上限で停止します。

評価、レビュー、コメント、Booklogタグ、profile要約、書名一覧、生CSVは送りません。検索文は保存せず、page単位SHA-256 digest、取得日時、件数だけを保存します。成功pageは30日、失敗pageは1時間再送せず、request間隔とHTTP 429 retryを制限します。Booklog全体のscrapingは行いません。

## プライバシー

- 本人がuploadした履歴だけを使い、原本を保存しない
- 個人履歴と公開推薦catalogをDBで分離し、個人履歴本をQMDへ索引しない
- Review本文・commentをMVP推薦へ利用しない
- ISBN書誌補完で外部へ送るのはISBNだけ
- 同意済み候補発見でだけ選択著者と公開由来カテゴリを送る
- 固定seedは全ユーザー共通で、個人履歴から生成しない
- 評価、レビュー、コメント、タグ、書名一覧、profile要約、生CSVを候補発見へ送らない
- Embedding、Query Expansion、Rerankerをlocal実行し、読書profileを外部LLMへ送らない
- 履歴、profile、推薦、feedbackを削除できる
- 匿名集計や協調Filteringには別途明示的同意が必要

## 現在の制約

- 認証なしの単一デモユーザー
- 書誌補完にはjob workerが必要。なくてもCSV情報で継続
- FallbackのVector/BM25値は軽量proxyでQMD model評価ではない
- Series情報が安定取得できず、title巻数表記による保守的判定
- QMD `--explain` はversion差を許容し、欠落値は `—`
- Local model初回downloadやCPU推論は時間がかかる
- 非同期生成は進捗率ではなくlifecycle stateを表示
- Google Books品質とquotaに依存。障害時は既存catalogで継続
- 書影は外部host依存。欠落時はlocal placeholder
- UI言語と読みたい本の言語はまだ別設定ではない

## 将来の協調フィルタリング

十分な同意済みユーザーデータが集まった段階で、既存Provider契約の後ろに `CollaborativeFilteringCandidateProvider` を追加します。共起数、cosine similarity、lift、Bayesian smoothing、人気度補正、最低共起数を評価します。データがない現段階で、見せかけの協調Filteringは実装しません。

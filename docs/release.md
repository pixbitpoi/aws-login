# リリース手順（Homebrew）

配布は個人用 tap [pixbitpoi/homebrew-tap](https://github.com/pixbitpoi/homebrew-tap) の
`Formula/aws-login.rb` で行います。formula はこのリポジトリのタグの tarball を参照します。
利用者向けの入れ方は [README.md](../README.md)「インストール」にあります。

## 配布物の範囲

配るのは `bin/aws-login` 1 ファイルだけです。formula の install はこの 1 行で終わります。

```ruby
bin.install "bin/aws-login"
```

依存が Bash と AWS CLI v2 だけで、本体が単一ファイルなので、`libexec/` への退避も env ラッパーも要りません。
ファイルを増やすときは、まずこの 1 行で済む形を保てないかを考えてください。

| 入らないもの | 理由 |
| --- | --- |
| `README.md`・`docs/` | 利用者向け文書の正本は GitHub（`brew home aws-login`）。配布物の中に読む手段が無く、参照する側も無い |
| `AGENTS.md`・`CLAUDE.md` | 開発時の入口。インストール済みのツリーの中で作業するエージェントはいない。開発は git clone で行う |
| `tests/` | 開発時にリポジトリで走らせる |

`README.md` を除外しても **keg 直下には現れます**。Homebrew が展開した tarball から metafile
（README・LICENSE など）を prefix へ複製するためです。これは Homebrew の作法なので止めません。
配布物として扱わない、という意味は**配布物の中の誰もそれを参照しない**ことです。

## 依存

AWS CLI v2 は `depends_on` にしません。公式インストーラーで入れている環境と二重になるためで、
caveats で案内します（[aws-survey](https://github.com/pixbitpoi/aws-survey) の formula と同じ扱い）。
jq は本体が使わないので不要です。

## 手順

1. 本体の `main` を push した状態で `bash tests/run.sh` を通してから、タグを打って push します。

   ```bash
   git tag -a v0.2.0 -m "v0.2.0"
   git push origin v0.2.0
   ```

2. GitHub が生成する tarball の sha256 を取得します。

   ```bash
   curl -sL https://github.com/pixbitpoi/aws-login/archive/refs/tags/v0.2.0.tar.gz | shasum -a 256
   ```

3. tap リポジトリの `Formula/aws-login.rb` で `url` のタグと `sha256` を更新します。
   `head` は `main` を指しているので変更不要です。

4. tap リポジトリで確認してからコミット・push します。

   ```bash
   brew style Formula/aws-login.rb
   brew audit --strict pixbitpoi/tap/aws-login
   brew install pixbitpoi/tap/aws-login
   brew test aws-login
   ```

   コミット件名は `aws-login 0.2.0` のように formula 名とバージョンを書きます。
   短い名前で `brew test` するには、事前に `brew trust pixbitpoi/tap` で tap を信頼しておきます。

タグは `vX.Y.Z` の形式にします。formula の `version` はタグから自動で決まるため、書きません。

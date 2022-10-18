# title

こんにちは。MIXI 開発本部 SREグループの [riddle](https://twitter.com/riddle_tec) です。

ビルドツールとして Bazel を利用していたのですが、いろいろあって make にしたので経緯や大変だったことを紹介します。

## 目次

# Bazel とは

Bazel は Google が開発したビルドツールで、Java、C++、Go、Android、iOS、その他多くの言語とプラットフォームを使用してビルドとテストができます。
特徴としてローカルやリモートでのキャッシュをうまく用い、アプリケーションのビルドやコンテナイメージの生成、テストなどさまざまなデプロイライフサイクルで活躍してくれます。

またルールを用意すれば Kubernetes にデプロイしてくれたり、シェルを実行してくれたりなどその適用範囲は非常に広いです。

- [Googleが開発する最新ビルドツール「Bazel」を使ってみよう | さくらのナレッジ](https://knowledge.sakura.ad.jp/6174/)
- [Bazelの解説（TS, Dockerイメージ、リモートキャッシュ）](https://zenn.dev/kesin11/books/c86010deb5b8008f394f)


# 速度はどうか？

軒並み同じか速くなりました。

# Bazel が大変だったこと

# Kubernetes でも除外されてる
他にもあったはず

- 元々の適用領域
    - test
    - container build & push
    - go get
    - code generator (pb系含む)
    - mock generator
- つらみ
    - ウイルススキャン
    - テストが遅い
    - bazelの書き方が独特できつい
        - 手を出したくない人が多かった
    - どう動いてるのか、高速化の方法がよくわからない
    - 並列実行できたりできなかったり…(hack
    - bazel rule のアップデート祭り(バージョン依存関係…)
    - 大量の差分(BUILD.bazel)
    - しばしばバージョンアップ
    - bazel のコンテナイメージが数GBあって重い
    - 
- よかった
    - リモートキャッシュ
    - 一度整備されればまあ、あんまり触ることもなく
    - 
- 移行後
    - make
    - 旧来の方法

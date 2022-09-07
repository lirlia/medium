# ゴーストスクランブルのバックエンドを支える技術

こんにちは。ミクシィの 開発本部 SREグループ の [riddle](https://twitter.com/riddle_tec) です。


https://youtu.be/kNGOW8RcBbA

ゴーストスクランブル（以下、ストブルと略します）は、弊社のモンストシリーズ最新作として2022年7月にリリースされたスマホゲームです。
マルチプレイとボイスチャット機能を搭載していて、最大4人でマルチプレイができるアクションゲームとなっています。

- [ゴーストスクランブル（ストブル）公式サイト](https://ghost-scramble.com/)


この記事でははじめてゲームの裏側を作った riddle が
どのようなバックエンド・インフラ構成でゲームが動いているかの紹介をします。


### 目次

# システムの全体像

ストブルのバックエンドでは以下の機能を提供しています。

1. gRPC でのリクエスト/レスポンス(アイテムを増減したり、スタミナを回復したり、ガチャをひいたりなど)
2. マルチプレイゲーム
3. ボイスチャット
4. 通知

## gRPC でのリクエスト/レスポンス

![picture 1](https://raw.githubusercontent.com/lirlia/medium/main/articles/2022-ghost-scramble-server/https://raw.githubusercontent.com/lirlia/medium/main/articles/2022-ghost-scramble-server/https://raw.githubusercontent.com/lirlia/medium/main/articles/2022-ghost-scramble-server/https://raw.githubusercontent.com/lirlia/medium/main/articles/2022-ghost-scramble-server/https://raw.githubusercontent.com/lirlia/medium/main/articles/2022-ghost-scramble-server/images/e5360d98d4d2e9bfefa4025911fd975c3cb738f489e1350d34f6a0ba4dd7e469.png)  

ゲームアカウント登録したり、ガチャをひいたり、アイテムを購入したりなど、
ゲームのうち永続性を持たせたい操作を担当する機能です。


一般的に API サーバと呼ばれるものですが、ストブルでは gRPC を利用しているので gRPC サーバと呼んでいます。

gRPC をゲームで使うのはチャレンジングな試みでしたが、Protocol Buffers の使用感が今のところいい感じです。
また、シリアライズのおかげで帯域をあまり消費しないのもうれしいですね。
※HTTP/2ベースで動くので End-to-Endで TLS 必須なところが開発時に厄介ですが…

また永続データは Spanner に、一時データは Cloud Memory Store for Redis に格納しています。

![picture 1](https://raw.githubusercontent.com/lirlia/medium/main/articles/2022-ghost-scramble-server/https://raw.githubusercontent.com/lirlia/medium/main/articles/2022-ghost-scramble-server/https://raw.githubusercontent.com/lirlia/medium/main/articles/2022-ghost-scramble-server/https://raw.githubusercontent.com/lirlia/medium/main/articles/2022-ghost-scramble-server/https://raw.githubusercontent.com/lirlia/medium/main/articles/2022-ghost-scramble-server/images/grpc.drawio.png)  

## マルチプレイゲーム

![picture 2](https://raw.githubusercontent.com/lirlia/medium/main/articles/2022-ghost-scramble-server/https://raw.githubusercontent.com/lirlia/medium/main/articles/2022-ghost-scramble-server/https://raw.githubusercontent.com/lirlia/medium/main/articles/2022-ghost-scramble-server/https://raw.githubusercontent.com/lirlia/medium/main/articles/2022-ghost-scramble-server/https://raw.githubusercontent.com/lirlia/medium/main/articles/2022-ghost-scramble-server/images/8dc8c4e26c929cda3a990f5f1d81901d535ab7b132b7b305d6a476d081df1e5a.png)  

ストブルでは4人で同時に遊べる **マルチプレイ** を売りにしています。
マルチプレイではサーバとの通信ではなく、ユーザー同士がパケットを交換して通信をするので専用のサーバが必要です。


モンストでは TURN サーバを利用していましたが、ストブルではプロトタイプ開発の容易さからモノビット社の `Monobit Unity Networking 2.0 (MUN)` を利用しています。

- [モンスターストライクのリアルタイム通信を支える技術 - ログミーTech](https://logmi.jp/tech/articles/321751)
- [Monobit Unity Networking 2.0 (MUN) - モノビットエンジン公式サイト](https://www.monobitengine.com/mun/)

MUN はホストOSを必要とする製品なので、コンテナではなく Compute Engine で動かしています。

![picture 1](https://raw.githubusercontent.com/lirlia/medium/main/articles/2022-ghost-scramble-server/https://raw.githubusercontent.com/lirlia/medium/main/articles/2022-ghost-scramble-server/https://raw.githubusercontent.com/lirlia/medium/main/articles/2022-ghost-scramble-server/https://raw.githubusercontent.com/lirlia/medium/main/articles/2022-ghost-scramble-server/https://raw.githubusercontent.com/lirlia/medium/main/articles/2022-ghost-scramble-server/images/multi.drawio.png)  

## ボイスチャット

![picture 3](https://raw.githubusercontent.com/lirlia/medium/main/articles/2022-ghost-scramble-server/https://raw.githubusercontent.com/lirlia/medium/main/articles/2022-ghost-scramble-server/https://raw.githubusercontent.com/lirlia/medium/main/articles/2022-ghost-scramble-server/https://raw.githubusercontent.com/lirlia/medium/main/articles/2022-ghost-scramble-server/https://raw.githubusercontent.com/lirlia/medium/main/articles/2022-ghost-scramble-server/images/1c9a0dcd8ebcf2c9ad9ced280d6b757ec8f27e9ee2967e2c8ae148f03f72cab1.png)  

よりマルチゲームを楽しんでもらうため、ストブルではボイスチャットを用意しています。
こちらは弊社のスーパーエンジニアが GKE + Agones で動くボイスチャットアプリを作ってくれました！

![picture 1](https://raw.githubusercontent.com/lirlia/medium/main/articles/2022-ghost-scramble-server/https://raw.githubusercontent.com/lirlia/medium/main/articles/2022-ghost-scramble-server/https://raw.githubusercontent.com/lirlia/medium/main/articles/2022-ghost-scramble-server/https://raw.githubusercontent.com/lirlia/medium/main/articles/2022-ghost-scramble-server/https://raw.githubusercontent.com/lirlia/medium/main/articles/2022-ghost-scramble-server/images/voice.drawio.png)  

詳しい構成や挙動は別の機会に紹介したいと思います。

## 通知

通知はゲーム中にフレンドからマルチプレイの招待をしたりするときに使う機能です。

これまで弊社では Web Socker や NATS サーバを自前で建てていたのですが、今回は通知に特化したサービスがあればよかったのでマネージドサービスの [Firebase Cloud Messaging(FCM)](https://firebase.google.com/docs/cloud-messaging?hl=ja) を採用し実現しています。

クライアントAがマルチプレイ用のルームを立て、フレンドを招待すると **クライアントA → gRPC サーバ → Firebase Cloud Messaging(FCM) → クライアントB(フレンド)** という流れで通知が飛びます。

![picture 1](https://raw.githubusercontent.com/lirlia/medium/main/articles/2022-ghost-scramble-server/https://raw.githubusercontent.com/lirlia/medium/main/articles/2022-ghost-scramble-server/https://raw.githubusercontent.com/lirlia/medium/main/articles/2022-ghost-scramble-server/https://raw.githubusercontent.com/lirlia/medium/main/articles/2022-ghost-scramble-server/https://raw.githubusercontent.com/lirlia/medium/main/articles/2022-ghost-scramble-server/images/notification.drawio.png)  

# ゲームの基盤の特性について

続いてゲームの基盤がどのような特性のもと設計されているのかを紹介します。

## スケーラビリティ

![picture 6](https://raw.githubusercontent.com/lirlia/medium/main/articles/2022-ghost-scramble-server/https://raw.githubusercontent.com/lirlia/medium/main/articles/2022-ghost-scramble-server/https://raw.githubusercontent.com/lirlia/medium/main/articles/2022-ghost-scramble-server/https://raw.githubusercontent.com/lirlia/medium/main/articles/2022-ghost-scramble-server/https://raw.githubusercontent.com/lirlia/medium/main/articles/2022-ghost-scramble-server/images/cf363ac328d387c11720afe2f5946bd4f9a945a5233f87cf0418d4df587239f8.png)  

通常の Web サービスと異なり、ゲームの基盤はトラフィックの増減が非常に激しいです。

たとえばリリース直後は大量のアクセスがありますが、その後はアクセス数がガクンと落ちます。
またイベントやキャンペーンといった販促活動を行うと大量のトラフィックが飛んでくることもあります。

※弊社のモンストでは年末年始に大きいイベントを開催しているため、それに向けて毎年チューニングを行ってます

そのためゲーム基盤はスケーラブルな構成にしておくことは必須で、さらにアクセスが減ったタイミングで最適な構成にするためスケールインを容易にしておく構成が求められます。よってデータベースリソースを小さくできる Cloud Spanner は相性がいいわけですね。


## セキュリティ

![picture 7](https://raw.githubusercontent.com/lirlia/medium/main/articles/2022-ghost-scramble-server/https://raw.githubusercontent.com/lirlia/medium/main/articles/2022-ghost-scramble-server/https://raw.githubusercontent.com/lirlia/medium/main/articles/2022-ghost-scramble-server/https://raw.githubusercontent.com/lirlia/medium/main/articles/2022-ghost-scramble-server/https://raw.githubusercontent.com/lirlia/medium/main/articles/2022-ghost-scramble-server/images/0c9a5e6af295689ae1c77426b7b1285dcd2fe0a1b70a7eba441068753a10bf22.png)  

bot といった不正ユーザからのアクセスや攻撃も多くとんでくるので、相応のセキュリティ対策も求められます。
実際ストブルもリリース直後に海外からの大量アクセスがとんできたので、Cloud Armor をつかって弾いたりしました。

## KPI 測定のためのログ収集

**「ゲームをどのように改善・更新していくか？」** を判断するため、「ユーザがどのクエストを遊んだのか？」「所持しているアイテムは何か？」など遊んでいただいたユーザのログを出力し、自前のデータ基盤にためて KPI 分析を行なっています。

![picture 1](https://raw.githubusercontent.com/lirlia/medium/main/articles/2022-ghost-scramble-server/https://raw.githubusercontent.com/lirlia/medium/main/articles/2022-ghost-scramble-server/https://raw.githubusercontent.com/lirlia/medium/main/articles/2022-ghost-scramble-server/https://raw.githubusercontent.com/lirlia/medium/main/articles/2022-ghost-scramble-server/https://raw.githubusercontent.com/lirlia/medium/main/articles/2022-ghost-scramble-server/images/data.drawio.png)  

## まとめ

まとめると基盤やバックエンドを設計・構築する際には「ゲームの機能を提供する」以外にもこれらの非機能要件も考えます。

- トラフィックの増減に応じてリソースを変動できる
- リソースを変動してもレイテンシーを維持する
- ユーザの不利益にならないようにセキュリティを高める
- 改善のための KPI 測定用のデータレイクの用意と分析

これらを満たすため、ストブルでは以下の構成でサービス提供を行なっています。

![picture 1](https://raw.githubusercontent.com/lirlia/medium/main/articles/2022-ghost-scramble-server/https://raw.githubusercontent.com/lirlia/medium/main/articles/2022-ghost-scramble-server/https://raw.githubusercontent.com/lirlia/medium/main/articles/2022-ghost-scramble-server/https://raw.githubusercontent.com/lirlia/medium/main/articles/2022-ghost-scramble-server/https://raw.githubusercontent.com/lirlia/medium/main/articles/2022-ghost-scramble-server/images/all.drawio.png)  

- 言語: Go
  - ボイスチャットで Elixir / Rust
  - 管理ツールで Ruby
- ビルド: Bazel
- サーバ：GKE / Google Compute Engine
- DB：Spanner / SQlite
- キャッシュ：MemoryStore for Redis
- マルチプレイ：MUN
- ボイスチャット：GKE / Agones
- CDN：Cloud CDN
- IaC: Terraform / Ansible
- CI : Cloud Build / GitHub Actions
- 通知：Firebase Cloud Messaging (FCM)
- 解析：DataFlow / PubSub / Google Cloud Storage / BigQuery
- 監視：Prometheus / Cloud Monitoring / PagerDuty / BugSnag

# さいごに

今回はざっくりストブルのバックエンド〜インフラで利用している技術を紹介しました。
個別の話や、リリースまでに色々と苦労したことについては別に記事にしようと思います！

# title

こんにちは。ミクシィの 開発本部 SREグループ の [riddle](https://twitter.com/riddle_tec) です。

### 目次
# 開発環境の話

わたしたちは開発環境に GKE を利用しています。

ゲーム開発ではエンジニアだけではなく、レベルデザインや敵キャラの配置、ダンジョンを作るプランナーも自由に個人開発環境を作りたいので、GKE 上に個々人の Namespace を作成し Pod を起動しています。

また Pod の外部公開には Ingress (裏側は Google の HTTPS LB) を使っています。

開発環境やそこで動く Pod の数は非常に多く、Ingress は **約 200 個** もあります。
また Pod は gRPC で通信を行なっているので Ingress に証明書も **約 200 個** 付与しています。

# 開発環境の問題点

開発環境は非エンジニアでも簡単に作成できるように、専用のツールをぽちぽちすれば作れます。
しかし、環境数が増えるにしたがって環境の作成がだんだんと遅くなってきました。

最初は証明書の発行に時間がかかっていたので 1 時間程度だったのですが、現在は 3 時間経っても終わらない状況でした。

よくよく確認すると新しく環境を作ると Ingress が Apply されるのですが、いつまでたっても HTTPS LB が作られていないことに気づきました。Google サポートに問い合わせたところ「Ingress Controller の仕様でプロジェクトに存在している Ingress の数 x 1分 だけ LB の作成、更新に時間がかかる」と回答いただきました。
※より詳細には「APIへのリクエストの処理が各ingress毎に相当の回数が必要で、キューに溜まっているリクエストを順次処理する仕組みのため」とのことです

- [Improve provisioning latency for ingress [171572578] - Visible to Public - Issue Tracker](https://issuetracker.google.com/issues/171572578)

つまり **201 個目** の Ingress を作成すると、HTTPS LB の作成までに **201 分(3時間超)** かかるというわけです。実際は、LB の作成が終わって IP アドレスが払い出されてから、さらに Google 管理の Managed Certificate と呼ばれる証明書を発行するのでさらに **1時間** かかるので、合計で環境作成に **4時間超** もかかることになります。

流石にこれは遅すぎますね。どうにかしたいです。

# いくつかの解決策

1. 個人環境数を減らす
2. 1 Namespace に 1 Ingress にする
3. 全員同じ Namespace にして Ingress を 1 つにする
4. リバースプロキシを立てて、URLごとに振り分ける

1 の「個人環境数を減らす」はインフラ都合で開発の効率を落とすのでよろしくないですね。
2 の「1 Namespace に 1 Ingress にする」はできるけど、環境数増えると元の木阿弥です。
3 の「全員同じ Namespace にして Ingress を 1 つにする」は Namespace を気軽に消せなかったり、リソース名のバッティングを今から考えるのが大変です。
4 の「リバースプロキシを立てて、URLごとに振り分ける」は本番環境と構成が変わりすぎるのでタイムアウトや、性能劣化に気づけない恐れがあります

ということであまりいい解決策がなかったので悶々としていました。

しかしある日ネットサーフィンをしていたところ Gateway API という、 Ingress の次の技術が出てきていてそれがユースケースにジャストフィットしていることに気づきました。これだ！！！

# Gateway API とは?

Ingress で実現したことが多すぎるので、より細かく LB 周りのリソースを使えるようにした Kubernetes リソースです。

GKE における Ingress では作成時にフォワーディングルールをきめたり、バックエンドの設定をしたり、IPアドレス、証明書、パス など様々な設定をしていました。

しかしこの図を見ていただくと、Gateway API では Google LB の各コンポーネントに対して別の Kubernetes Resource が割り当てられています。
![picture 2](images/6e0b09626d5e36ef5edec16bd99fe400f7a908e91d755a1031fe21139e773114.png)  
https://medium.com/google-cloud-jp/gke-gateway-4150649d8c37 より引用

これにより Platform Admin(いわゆるインフラ担当)が LB や証明書を管理しつつ、どのパスのときにどの Pod に通信させるのか？を各サービスオーナー(いわゆる開発者)を別々に管理することができます。

![picture 3](images/9a5278cf3aab0d3485ef4b0a05d227b8a555663272323fd2b56b161b7773a959.png)  


Gateway API について詳しく紹介してくれているブログがあるので詳細はこちらをご覧ください。
- [Ingress の進化版 Gateway API を解説する Part 1 (シングルクラスタ編) | by Kazuu | google-cloud-jp | Medium](https://medium.com/google-cloud-jp/gke-gateway-4150649d8c37)
- [動作検証しながら理解する「Kubernetes Gateway API」と「GKE Gateway Controller」 - ZOZO TECH BLOG](https://techblog.zozo.com/entry/gke-controller-verification#%E5%88%A9%E7%82%B91%E3%83%AB%E3%83%BC%E3%83%86%E3%82%A3%E3%83%B3%E3%82%B0%E3%81%AE%E8%A8%AD%E5%AE%9A%E3%81%AB%E5%BF%85%E8%A6%81%E6%9C%80%E5%B0%8F%E9%99%90%E3%81%AA%E6%A8%A9%E9%99%90%E3%82%92RBAC%E3%81%A7%E4%BB%98%E4%B8%8E%E3%81%A7%E3%81%8D%E3%82%8B)

---

Gateway API を使うと何が嬉しいのかというと、Gateway を 1つとワイルドカード証明書を1個作れば、リクエストをどの Pod に飛ばすルールを Namespace ごとに書けば、Pod を外部に公開できるところです。

Ingress を **200 個** も作らなくて済むし、今後環境が増えても LB や証明書が増えることがないんです！！（ただし、別ドメインの Pod が増えるなら証明書は増える）

# Ingress から Gateway API に移行してみた
## 注意点

Gateway API にはいくつか制限があります。

詳細はこちら。

- [プレビューの制限と既知の問題  |  Kubernetes Engine ドキュメント  |  Google Cloud](https://cloud.google.com/kubernetes-engine/docs/how-to/deploying-gateways?hl=ja#limitations)

幸い自分たちは問題ありませんでしたが、コンソール上で見れないのはいざという時困りそうです。

> 現在、Gateway によって作成された Google Cloud ロードバランサのリソースは、Google Cloud Console UI には表示されません。

## 実際の移行方式

Ingress + Managed Certificate の環境から
Gateway API + Certificate-Manager に引っ越しました。

# 待ってました Certificate-Manager !

- ワイルドカード証明書

# 困ったこと
## 謎のエラー

以下の manifest を使ってデプロイしたところ

```yaml
kind: Gateway
apiVersion: gateway.networking.k8s.io/v1beta1
# https://gateway-api.sigs.k8s.io/references/spec/#gateway.networking.k8s.io/v1beta1.Gateway
metadata:
  name: https
  namespace: infra
  annotations:
    networking.gke.io/certmap: test-map
spec:
  gatewayClassName: gke-l7-gxlb
  listeners:
  - name: https
    protocol: HTTPS
    port: 443
```

見たことないエラーが出てきました。ドキュメントを読んでも権限設定が不要なので迷ってました。

```
failed to initialize Translator GCE Env for Gateway "infra/durian-https": RPC::CREDS_POLICY_REJECTED_ERROR: ListCertificateMaps(): RPC: Rejected by RpcSecurityPolicy: generic::unauthenticated: Rejected by creds_policy (neither auth.creds.useLOAS nor auth.creds.useNormalUserEUC granted): Permission 'auth.creds.useLOAS' not granted to gke-gateway-controller@prod.google.com with realm 'campus-iza', because a DENY rule was triggered: {description: "By default, allow requests from self realm, remote yawn, self cloud region, or from a person user (in corp or any realm, including via Borg jobs)" permissions: "*" action: DENY not_in: "mdb:all-person-users" conditions { iam: SECURITY_REALM op: NOT_IN values: "self" values: "realms-for-yawns" values: "self:cloud-region" }}.; RpcSecurityPolicy={http://rpcsp/p/r6of5vALEm3BM4qxK2f9SCaWSQMvqa1vNGWBg9YJMYw}
```


# まとめ

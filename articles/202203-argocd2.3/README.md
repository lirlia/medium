# Argo CD 2.3.0 にアップデート時にやったことを紹介します

こんにちは。ミクシィの 開発本部 SREグループ の [riddle](https://twitter.com/riddle_tec) です。

Argo CD が v2.3.0 がリリースされました！

- [Argo CD v2.3 release candidate. The next Argo CD release is around the… | by Alexander Matyushentsev | Feb, 2022 | Argo Project](https://blog.argoproj.io/argo-cd-v2-3-release-candidate-a5b8cf11b0d3)
- [argo-cd/2.2-2.3.md at v2.3.0 · argoproj/argo-cd](https://github.com/argoproj/argo-cd/blob/v2.3.0/docs/operator-manual/upgrading/2.2-2.3.md)


早速バージョンアップをしたので、実施した手順を紹介します。

## 前提情報

私たちがバージョンアップしたときの環境情報はこちらです。

- `v2.2.3` → `v2.3.0` にアップデートした。
- Argo CD Notifications(`v.1.1.0`) を使っている。
- `kubeconform` によるスキーマチェックをしている。
- Helm パッケージの保存に OCI 準拠の Artifact Registry を使っている。

# Argo CD 2.3 のアップデート内容

![picture 2](images/1996107b2d0a9f111633233aacff75764d8993443417c3a2f1d2044f7ff9be07.png)  

対応が必要だったアップデートを列挙します。(私たちの場合)

- Argo CD Notifications / ApplicationSet が 1 リポジトリに集約された
- Argo CD 内の `Kustomize` のバージョンアップ 4.2.0 → 4.4.1
- Argo CD 内の `Helm` のバージョンアップ 3.7.1 → 3.8.0
- 新しい Sync And Diff Strategies が登場した(`RespectIgnoreDifferences/managedFieldsManagers`)

# 作業内容

![picture 1](images/11beb0b14ffabc1db66ecfe1b18798163183d194441c842a0e963a899dd18037.png)  

以下の順に作業を進めました。

1. 既存の manifest への `Kustomize` / `Helm` バージョンアップの影響調査
1. 更新された CRD から[スキーマチェック](https://mixi-developers.mixi.co.jp/kubeconform-2bb477371e06)用のスキーマを生成
1. 古い Argo CD Notifications を削除
1. Argo CD v2.3.0 にアップデート
1. `export HELM_EXPERIMENTAL_OCI=1` を削除
1. `RespectIgnoreDifferences` の設定を行う

## `Kustomize` / `Helm` バージョンアップの影響調査

`Kustomize / Helm` の GitHub Release を見て変更内容を把握した上で

- manifest が生成できるかどうか？
- 生成した manifest は現状と差分がないか？

を確認しました。

私たちの場合、特に差分や問題はありませんでした。

ただし、ユーザの環境によっては特定バージョンの `kustomize` や `helm` を使いたいケースもあると思います。その場合は Argo CD の設定でバージョンを指定できます。(参考情報: [kustomizeをv4.4.0にバージョンアップしました](https://studist.tech/kustomize-v4-9f3f0086b719))

## スキーマの生成

私たちは `kubeconform` で manifest のスキーマチェックをしています。

そのため新しい CRD のスキーマを生成する必要がありましたが、自動化しているのであっさり終わりました。(便利!)

スキーマの自動化を紹介した記事はこちらです。

- [kubeconformで使うスキーマをGitHub Actionsで自動生成して楽しよう！](https://mixi-developers.mixi.co.jp/kubeconform-generate-schema-412c02f081de)

## 古い Argo CD Notifications の削除

現状 k8s 上で動いているアプリを削除しただけです。

Argo CD を使っているので、対応する `Application` を削除してあとは GitOps に任せました。

![picture 2](images/aa5ee8ce55b61269621e7194ff42195a7b76269e75acb8b0bf656cf5b1a57653.png)  

## Argo CD v2.3.0 にアップデート

Argo CD v2.3.0 の manifest を以下の方法で取得して Git に格納しました。

```sh
kustomize build "github.com/argoproj/argo-cd/manifests/ha/cluster-install?ref=v2.3.0" > upstream.yaml
```

ここに **旧 Argo CD Notifications の設定を移動** したら、コミットしてあとは GitOps に任せます。

これだけでバージョンアップ完了です。(簡単!)

※私たちのケースでは旧 Argo CD Notifications で使っていた ConfigMap(`argocd-notifications-cm`) をそのまま使用できました

## `export HELM_EXPERIMENTAL_OCI=1` の削除

私たちは2種類のリポジトリで manifest を管理している都合上、Google Cloud の Artifact Registry に Helm パッケージを格納しています。(詳細は[HelmのvaluesとChartが別リポジトリの時にArgoCDでデプロイする方法](https://mixi-developers.mixi.co.jp/argocd-with-helm-7ec01a325acb)をご覧ください)

Artifact Registry に格納する場合は、 Helm パッケージを OCI 準拠のイメージとして生成しなければなりません。OCI 準拠のイメージを作成する機能は実験的な機能のため `Helm 3.7.1` では `export HELM_EXPERIMENTAL_OCI=1` を実行する必要があります。

```sh
export HELM_EXPERIMENTAL_OCI=1

gcloud auth print-access-token --project "$PROJECT_ID" \
    | helm registry login -u oauth2accesstoken --password-stdin https://asia-northeast1-docker.pkg.dev

# 必要な外部パッケージを取得(Chart.yaml に書かれている事が前提)
helm dependency update xxx

# manifests の作成
helm template xxx --include-crds > xxx.yaml
```

しかし Argo CD v2.3.0 に内包された `Helm 3.8.0` では標準で OCI 準拠のイメージを作成できるようになったので、これまで使っていた `export HELM_EXPERIMENTAL_OCI=1` を全体的に削除できるようになりました。


## `RespectIgnoreDifferences` の設定を行う

この設定を説明するために、まずは **「Argo CD が差分を無視した同期をどのように行うか」** を紹介します。

この `Application` 設定で

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
〜省略〜
spec:
〜省略〜
  ignoreDifferences:
  - group: apps
    kind: Deployment
    jsonPointers:
    - /spec/replicas
```

Nginx の Deployment を管理しているとします。

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
  labels:
    app: nginx
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        ports:
        - containerPort: 80
```

Argo CD には **意図的に差分を無視する** `ignoreDifferences` という設定があります。`spec.ignoreDifferences[].jsonPointers` で Deployment の `replicas` を無視しているので、HPA が `replicas` を 2 に変更しても Argo CD は Git と同期を行ないません。

しかし Deployment の `metadata/labels` を変更するコミットが積まれた場合、Argo CD は無視しているはずの `replicas` の設定を含めて更新を行うため、`replicas` が 1 に戻ります。これによって HPA は再び `replicas` を 2 に戻します。

※HPA を例にとりあげていますが、Argo CD 管理のパラメータを制御するアプリであればなんでも OK です

HPA によって管理された `replicas` を Argo CD が更新するのを避けるため、Argo CD の[マニュアル](https://argo-cd.readthedocs.io/en/stable/user-guide/best_practices/#leaving-room-for-imperativeness)では **「`replicas` を manifest に含めないこと」** というワークアラウンドを提示しています。

こうですね。

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
spec:
  # do not include replicas in the manifests if you want replicas to be controlled by HPA
  # replicas: 1
  template:
    spec:
      containers:
      - image: nginx:1.7.9
        name: nginx
        ports:
        - containerPort: 80
...
```

しかし `replicas` が埋め込まれている外部の **Helm チャート**や **kustomization.yaml** ではこの方法が使えません。

そこで Argo CD v2.3.0 ではこの問題を回避する**2つの機能が追加**されました。

1. Argo CD の `ignoreDifferences` の無視対象を sync 時にも使う
    - `sync option(RespectIgnoreDifferences=true)`
2. 特定のコントローラーによる manifest の差分を Argo CD が無視する(同期しない）
    - `ignoreDifferences` で `managedFieldsManagers` を指定

参考

- [New sync and diff strategies in ArgoCD | by Leonardo Luz | Jan, 2022 | Argo Project](https://blog.argoproj.io/new-sync-and-diff-strategies-in-argocd-44195d3f8b8c)
- https://github.com/argoproj/argo-cd/issues/2913#issuecomment-978001260

今回、私たちは手軽に使用できる `RespectIgnoreDifferences` を設定しました。

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
〜省略〜
spec:
〜省略〜
  ignoreDifferences:
  - group: apps
    kind: Deployment
    jsonPointers:
    - /spec/replicas

  syncPolicy:
    syncOptions:
    # ignoreDifferences で無視した差分を sync 時にも無視する
    # see: https://argo-cd.readthedocs.io/en/latest/user-guide/sync-options/#respect-ignore-difference-configs
    - RespectIgnoreDifferences=true
```

`syncPolicy.syncOptions[].RespectIgnoreDifferences=true` を設定するだけなので楽ちんです。

# まとめ

![picture 3](images/4d07fe670d4d363596c8d2f981cf5eaaf5ea56ac9728da5bbb955ddcc0541c7e.png)  

マイナーバージョンが 1 上がっただけにしては色々変更がありますが、古いままだとセキュリティリスクもありますので頑張ってアップデートしましょう！

Argo CD v2.3.0 のその他のアップデートや注意点などは公式サイトを参照してください。

- [Argo CD v2.3 release candidate.](https://blog.argoproj.io/argo-cd-v2-3-release-candidate-a5b8cf11b0d3)
- [argo-cd/2.2-2.3.md at v2.3.0 · argoproj/argo-cd](https://github.com/argoproj/argo-cd/blob/v2.3.0/docs/operator-manual/upgrading/2.2-2.3.md)

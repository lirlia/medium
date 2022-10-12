# GKE NodePool の変更をダウンタイム無しで行う Terraform module を作った

こんにちはMIXI 開発本部 SREグループ の [riddle](https://twitter.com/riddle_tec) です。

GKE 使ってますか？

私達のチームでは GKE を始めとするインフラリソースの管理を Terraform で行っています。

![picture 17](https://raw.githubusercontent.com/lirlia/medium/main/articles/202202-terraform-nodepool/images/8123cc7edaa6efbd3716aaf3b69d596138ea20a2e09377ebe24b3034afaee504.png)

非常に便利なのですが、Terraform で NodePool の変更する時に内容によっては **「NodePool の削除 -> NodePool の作成 という順番で Terraform が動作してしまうこと**」に困っていました。

![picture 18](https://raw.githubusercontent.com/lirlia/medium/main/articles/202202-terraform-nodepool/images/f90988f965014fc58b774eaed6d6d36dd35595f3d665e47a40ccc03f6613e008.png)  

例えば NodePool のインスタンスタイプの変更作業を行った際に NodePool に存在するすべての Pod にアクセスができなくなってしまうのです。(Pod が nodeSelector や nodeAffinity で削除する NodePool でのみ動くことを想定しています)

1. NodePool(A) の削除
1. NodePool(A) 上の Pod はすべて Pending になる
1. NodePool(B) の作成
1. NodePool(B) 上で Pod が起動しはじめる

これを回避するためには以下の手順を行う必要があります。

1. 新しい NodePool を作成 (nodeSelector などが満たせる新しい NodePool を作る)
1. 既存の NodePool を cordon して Pod のスケジューリングを禁止する
1. 既存の NodePool を drain して 新しい NodePool に Pod を移動する
1. 古い NodePool を削除する

![picture 19](https://raw.githubusercontent.com/lirlia/medium/main/articles/202202-terraform-nodepool/images/3b24bd372a18ddd4ec4588973c94cc9f2cb2b04481eac2dd61e39599cc9c292e.png)  

これが**ひじょーーーーーに面倒**で、Pull Request ベースで Terraform コードを管理している我々の環境では、少なくとも2回のコード修正(NodePool の作成/削除)を行う必要がありますし、何より**手作業で kubectl cordon / kubectl drain コマンドを叩くところが辛い**です。

そこで作った（厳密には改造）のが **NodePool の作成/更新が簡単にできる Terraform module** です。
- [lirlia/terraform-google-gke-node-pool](https://github.com/lirlia/terraform-google-gke-node-pool)

※上記の module の多くはこちらを使わせていただいております(ありがとうございます!!)
- [baozuo/terraform-google-gke-node-pool: A Terraform module to create GKE node pool featuring zero downtime during recreation](https://github.com/baozuo/terraform-google-gke-node-pool)

## terraform-google-gke-node-pool とは
![picture 20](https://raw.githubusercontent.com/lirlia/medium/main/articles/202202-terraform-nodepool/images/4bbf4d930fa146cb50b492d87781ea09e510b95dfea21f1ce44e4828b0b78c3e.png)

この module を使うと Terraform のコードを修正するだけで **ダウンタイムなしで NodePool の更新**ができます。(`kubectl drain` 時にダウンタイムが発生しないように `PodDisruptionBudget` などが設定されていることが前提です)

具体的には以下の手順になります。

1. NodePool の修正を行うコードを書く(例: インスタンスタイプの変更)
2. `terraform apply` でコードを流す

非常に簡単ですね！！

## module の使い方

module をダウンロードしていただいて、以下のように呼び出せば使用できます。

```terraform
module "nodepool" {
  source             = "this module path"
  project_id         = "YOUR-GCP-PROJECT-ID"
  prefix             = "YOUR-NODEPOOL-PREFIX"
  cluster_name       = "YOUR-CLUSTER-NAME"
}
```

## module がやっていること

![picture 21](https://raw.githubusercontent.com/lirlia/medium/main/articles/202202-terraform-nodepool/images/326941769696ba33cf7dc73cffe2fc290927ff3f4b73eddab6c469e302487d1c.png)

では module がどのような仕組みで動いているのかを追っていきます。

通常 Terraform で NodePool の再作成を伴う更新の際は

- NodePool の削除
- NodePool の作成

という順番になります。まずはこれを逆(`作成 → 削除`)にしたいですね。そこで `create_before_destroy = true` を使って、先に NodePool を作成するように宣言します。

```terraform
resource "google_container_node_pool" "node_pool" {

  ...

  lifecycle {
    create_before_destroy = true
  }

  ...
}
```

しかしこのままだと同名の NodePool が作成されてしまう(=同名では作成できないのでエラーとなる)ので、NodePool 名を変更する必要があります。

そのため `random_id` リソースを使って特定の変更が走ったときのみランダムな名前を生成し、新しい名前で NodePool を作成するようにしています。

```terraform
resource "google_container_node_pool" "node_pool" {
  name               = random_id.node_pool_name.hex
  ...
}

resource "random_id" "node_pool_name" {
  byte_length = 2
  prefix      = format("%s-pool-", var.prefix)

  # 以下の変数が変更された場合は名前を再作成して NodePool を作り直します
  # NodePool が再作成される設定変更はここに追記していってください
  keepers = {
    gke_version    = var.gke_version
    disk_size_gb   = lookup(var.config, "disk_size_gb", "")
    disk_type      = lookup(var.config, "disk_type", "")
    machine_type   = lookup(var.config, "machine_type", "")
    preemptible    = lookup(var.config, "preemptible", "")
    labels         = join(",", sort(concat(keys(var.labels), values(var.labels))))
    tags           = join(",", sort(concat(var.tags)))
    oauth_scopes   = join(",", sort(concat(var.oauth_scopes)))
    node_locations = join(",", sort(var.node_locations))
  }
}
```

---

続いて NodePool が作成された後に、削除対象の NodePool 上の Pod を drain する方法について紹介します。

Terraform では `null_resource` を用いることで Terraform では本来制御できないオブジェクトの操作が可能になります。

ここでは `triggeers` で指定した変数が変更された場合(大事なのは `node_pool_name` が変更された場合 = 新しい NodePool が作成された場合)に `${path.module}/scripts/drain-nodes.sh` が実行されます。

```terraform
resource "null_resource" "node_pool_provisioner" {
  triggers = {
    project_id         = var.project_id
    cluster_name       = var.cluster_name
    location           = var.location
    node_pool_name     = random_id.node_pool_name.hex
    drain_interval_sec = var.drain_interval_sec
  }

  # Node Pool が 削除される際にスクリプトを実行して Drain を行います
  provisioner "local-exec" {
    command = <<-EOT
      ${path.module}/scripts/drain-nodes.sh \
        --project_id ${self.triggers.project_id} \
        --location ${self.triggers.location} \
        --cluster_name ${self.triggers.cluster_name} \
        --node_pool_name ${self.triggers.node_pool_name} \
        --drain_interval_sec ${self.triggers.drain_interval_sec}
    EOT
  }

  depends_on = [
    google_container_node_pool.node_pool,
    random_id.node_pool_name,
  ]

  lifecycle {
    create_before_destroy = true
  }
}
```


`depends_on` で `google_container_node_pool` リソースに対して依存関係を定義しているので以下の順で処理が行われます。

1. NodePool の作成
1. `null_resource` の実行(drain 処理)
1. NodePool の削除

※ `create_before_destroy` と `depends_on` を併用した場合の挙動は [Terraform 公式の解説](https://github.com/hashicorp/terraform/blob/2cd1619c40124116cc65350c2c321479ce5237b9/docs/destroying.md#create-before-destroy)がわかりやすいので参照してください

続いて `drain-nodes.sh` の内容です。まとめるとこれしかやっていません。

1. 古い NodePool の `autoscaling` 設定を無効化
1. 古い NodePool に対して `kubectl cordon / kubectl drain` を実行

※手順は [Google Cloud のドキュメント](https://cloud.google.com/kubernetes-engine/docs/tutorials/migrating-node-pool)に記載されている内容です

まずは drain した際に古い NodePool が AutoScaling して Pod が配置されないようにします。(ループしているのは複数の NodePool に対して変更を加えているとタイミングによって失敗するためです)

```bash
until gcloud container node-pools update "$old_node_pool" --no-enable-autoscaling "${GCLOUD_NODEPOOL_CMD_ARGS[@]}"
do
    echo "Waiting for the old node pool $old_node_pool to disable autoscaling..."
    sleep 20
done
```

続いて drain を行ないます。ループしてコマンドを叩いているだけですね。

```bash
# 削除する NodePool の Node に対して Cordon を実行して Pod がスケジュールされないようにします
echo "Cordoning nodes... ($old_node_pool)"
kubectl get nodes -l "cloud.google.com/gke-nodepool=$old_node_pool" -o=name | xargs -I{} kubectl cordon {}

# 削除する NodePool の Node に対して Drain を実行して Pod を移動します
# 処理は 1 Node づつ行われます
echo "Draining nodes..."
for node in $(kubectl get nodes -l "cloud.google.com/gke-nodepool=$old_node_pool" -o=name); do
    echo "Draining node $node"
    kubectl drain --force --ignore-daemonsets --delete-emptydir-data "$node"
    # 次の Node を Drain するまで一定時間待ちます
    # すべての リソースに PodDisruptionBudget が設定されていれば DRAIN_INTERVAL_SEC は0で構いません
    sleep "$DRAIN_INTERVAL_SEC"
done
```

この処理が正常に完了すれば後は Terraform が古い NodePool を削除するだけです。

## まとめ

ということで `terraform-google-gke-node-pool` の裏側の紹介でした！

![picture 23](https://raw.githubusercontent.com/lirlia/medium/main/articles/202202-terraform-nodepool/images/8d66f312f734cc90b7c889a25c059fbe0f0162e016439f5239f747f655115a37.png)

GKE の NodePool の更新作業は非常に面倒なのでぜひ使って楽してみてください！
- [lirlia/terraform-google-gke-node-pool](https://github.com/lirlia/terraform-google-gke-node-pool)

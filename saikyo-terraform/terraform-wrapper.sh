#!/bin/bash

#
# このスクリプトは terragrunt の実行結果を terraform に渡して、
# terraform の実行を行うために利用します
#
# terragrunt -> 本スクリプト -> terraform の順に呼び出されます
#

# set -x
set -o pipefail
set -o nounset
set -o errexit

function usage () {
    CMDNAME="${0##*/}"
    cat <<USAGE >&2
Usage:
    $CMDNAME [Terraform command line args]
USAGE
}

function prefail () { echo "$@" 1>&2; exit 1; }
function _catch () {
    original_exit=$?

    # 実行に失敗したターゲットのファイルを生成する(これを集計する)
    [ $original_exit -ne 0 ] && touch "${TF_TMPDIR}/${TARGET_STATE_NAME}_terraform_fail.log"

    exit $original_exit
}

# 出力を === で囲って出力する
# 例: 以下のようになる
#
# ==========================================================================
# terraform init
#==========================================================================
function bar () {
    local line
    local column=120
    line=$(seq -s= $column | tr -d '[:digit:]')
    echo $line
    IFS=''
    while read -r data; do
        echo "$data"
    done
    echo $line
}

# 出力がまじるので出力の先頭に TARGET_STATE_NAME を付与する
# 例: environments_development_gke-cluster: が出力の行頭につく
function add_target_name () {
    IFS=''
    # mac で動作させる時は sed: RE error: illegal byte sequence 対策のため LC を指定する
    while read -r data; do
        echo "$data" | LC_ALL=C sed -e "s/^/${TARGET_STATE_NAME}: /g"
    done
}

# add_target_name と bar を付与して echo を実施します
function echo_plus () {
    echo "$@" | add_target_name | bar
}

trap _catch EXIT

#
# 変数宣言
#

# 例: terraform/live/environments/development/other のディレクトリで terraform を実行する場合
# 出力を見分けるために environments_development_other を TARGET_STATE_NAME に格納する
PARENTS_PWD=$(cd ../../.. ; pwd)
TARGET_STATE_NAME=$(pwd | sed -e "s@${PARENTS_PWD}/@@g" | sed -e "s@\/@_@g") # PARENTS_PWD に / が含まれるので区切り文字を @ にする

: ${TF_TMPDIR:="/tmp/terragrunt"} # 作業用ディレクトリ
TF_LOG_NAME_FILENAME="${TF_TMPDIR}/${TARGET_STATE_NAME}_terraform.log" # Terraform の出力結果を格納するファイル名
TF_STATE_FILENAME="${TF_TMPDIR}/${TARGET_STATE_NAME}_terraform.state"  # ローカルにダウンロードする Terraform ステートの名前

# Terraform 引数設定
TF_ARGS=(${@:-""})     # コマンドライン引数
TF_ARGS+=("-no-color") # GitHub 通知時にカラーだと整形し辛いので色無しにする

# Terraform Plan / Apply 時に利用する引数
TF_PLAN_APPLY_ARGS=(
    "-refresh=false"
    "-lock-timeout=${TF_LOCK_TIMEOUT:-300s}"
)

# Terraform Refresh で必要な -var-file に関するオプションのみを取得する
TF_REFRESH_ARGS=($(echo "${TF_ARGS[@]}" | xargs -n 1 | grep 'var-file' || true))

# 出力用ファイル格納用のディレクトリの作成
mkdir -p "${TF_TMPDIR}"

#
# Terraform 実行
#

# ◆ version
# Terragrunt が Plan や Apply を行う際は、事前に terraform version を実行するので
# 引数の先頭に version が存在するかをチェックして終了する
# ※ Terragurant が terraform --version / terraform version の両方を実行するため正規表現でマッチさせる
[[ "${TF_ARGS[0]}" =~ "version" ]] && terraform version && exit 0

# ◆ output
# Terragrunt が Module 間で変数をやり取りするときに terraform output を実行するので
# 引数の先頭に output が存在するかをチェックして終了する
# このとき Terragrunt が指定する引数をそのまま使う必要がある
[ "${TF_ARGS[0]}" = "output" ] && terraform "${TF_ARGS[@]}" && exit 0

# ◆ 共通
# module / provider を用意する
echo_plus "terraform init"
terraform init | add_target_name

case "${TF_ARGS[0]}" in
    #
    # 【ローカルにステートをダウンロードする理由】
    # terraform plan を実行すると Terraform のステートのロックを獲得して処理が行われる。
    # このとき terraform plan プロセスがキャンセルされるとロックを解除しない場合があるため、
    # ロックを獲得せずに済むようにあらかじめ Terraform のステートをダウンロードして処理を行う。
    # ※上記は CI のジョブをキャンセルする際に発生することがある
    #
    # 仮に -lock=false をつけて場合は、ロックを保持しないが CI で複数の terraform plan が走った場合に
    # 各々の CI が Terraform のステートを更新してしまい意図しない状態に書き換えられてしまうため、-lock=false は使用しない。
    #
    # 処理の流れ: init -> state をダウンロード -> init --reconfigure -> refresh -> plan
    "plan")

        echo_plus "terraform state pull"
        terraform state pull > "$TF_STATE_FILENAME"

        # ダウンロードしたステートファイルを利用するために作成する
        cat << BACKEND > $(pwd)/backend_override.tf
        terraform {
            backend "local" {
                path="$TF_STATE_FILENAME"
            }
        }
BACKEND

        # 新しい backend を使用するため reconfigure する
        echo_plus "terraform init -reconfigure"
        terraform init -reconfigure | add_target_name

        echo_plus "terraform validate"
        terraform validate | add_target_name

        # terraform plan の結果に余計な情報を付与しないため先に実行する
        echo_plus "terraform reflesh"
        terraform refresh ${TF_REFRESH_ARGS[@]} | add_target_name

        TF_ARGS+=(${TF_PLAN_APPLY_ARGS[@]})
        ;;

    # 処理の流れ: init -> refresh -> apply
    "apply")

        # terraform apply の結果に余計な情報を付与しないため先に実行する
        echo_plus "terraform reflesh"
        terraform refresh ${TF_REFRESH_ARGS[@]} | add_target_name

        TF_ARGS+=(${TF_PLAN_APPLY_ARGS[@]})
        ;;
    *)
        true
        ;;
esac

# terraform の実行
echo_plus "terraform ${TF_ARGS[@]}"
terraform ${TF_ARGS[@]} 2>&1 | add_target_name | tee "$TF_LOG_NAME_FILENAME"

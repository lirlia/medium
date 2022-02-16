#!/bin/bash

#
# このスクリプトは terraform-wrapper.sh で生成されたファイルを整形し、
# GitHub に投稿可能な markdown 形式のコメントを標準出力します
#

#set -x
set -o pipefail
set -o nounset
set -o errexit

function prefail() { echo "$@" 1>&2; usage; exit 1; }

function usage() {
    CMDNAME=${0##*/}
    cat <<USAGE >&2

Usage:
    $CMDNAME [OPTIONS]

Options:
    --type [plan/apply]         Terraform の実行結果の種類を指定してください (default: plan)
    --log_dir [DIR_NAME]        Terraform の実行結果が格納されているパスを指定してください (default: /tmp)
    --project_id [PROJECT_ID]   実行された GCP プロジェクト ID を指定してください
    --stage [STAGE]             実行された環境名を指定してください
    --build_url [BUILD_URL]     実行されたジョブの URL を指定してください
    --enable_post_slack         GitHub に投稿したコメントを GitHub Action が Slack に通知できるようにコメントを追加します (default: disable)
                                (Slack に投稿する機能はこのスクリプトでは実装されていません)
    -h, --help

USAGE
}

TF_TYPE=plan
TF_LOG_DIR=/tmp
PROJECT_ID=dummy_pj
STAGE=dummy_env
BUILD_URL=dummy_url
SLACK_FLAG=false
# GitHub の Issue に投稿可能な最大の文字数
MAX_GITHUB_ISSUE_BODY_CHARACTER_COUNT=65535

# コメント通知時に追加されるヘッダやURLなどの文字数です
# この値は暫定値のため Terraform state などが増えた場合は増やしてください
COMMENT_METADATA_CHARACTER_COUNT=2000

# terraform の差分を出力しない場合は true にしてください
ENABLE_DETAIL_TRUNCATE=false

# コマンドライン引数
while [[ $# -gt 0 ]]; do
    case "$1" in
    --type)
        TF_TYPE="$2"
        [[ ! $TF_TYPE =~ ^plan$|^apply$ ]] && prefail "invalid --type: $TF_TYPE"
        shift 2
        ;;
    --log_dir)
        TF_LOG_DIR="$2"
        shift 2
        ;;
    --project_id)
        PROJECT_ID="$2"
        shift 2
        ;;
    --stage)
        STAGE="$2"
        shift 2
        ;;
    --build_url)
        BUILD_URL="$2"
        shift 2
        ;;
    --enable_post_slack)
        SLACK_FLAG="true"
        shift 1
        ;;
    --help|-h)
        usage
        exit 0
        ;;
    *)
        prefail "Unknown argument: $1"
        ;;
    esac
done

#
# 1. terraform plan / apply の出力結果を見て差分あり/なしの整理を行う
#

cd "$TF_LOG_DIR"
TF_CHANGE_LIST="$TF_LOG_DIR/change_list"
TF_NOCHANGE_LIST="$TF_LOG_DIR/no_change_list"

# ローカル開発用に空にする
: > $TF_CHANGE_LIST
: > $TF_NOCHANGE_LIST

# terraform plan / apply 実行時に 「No changes. Your infrastructure matches the configuration. 」
# が出力されているので、その有無で差分のあり/なしを分割する

set +o errexit # ローカルでは find 時に Permission Denied でエラー終了するので一時的に外す

    for f in $(find * -name '*_terraform.log' -mindepth 0 -maxdepth 0 2>/dev/null)
    do
        # TF_NOCHANGE_LIST の内容はそのまま markdown のリストにするため - をつけている
        grep -q 'No changes' $f \
            `# 差分なし` \
            && echo "- $f" >> $TF_NOCHANGE_LIST \
            `# 差分あり` \
            || echo "$f" >> $TF_CHANGE_LIST
    done

    # terraform plan / apply 実行に失敗した一覧を取得
    TF_FAIL_LIST=("$(find * -name '*_terraform_fail.log' -mindepth 0 -maxdepth 0 2>/dev/null)")

set -o errexit

#
# 2. GitHub コメントを生成する
#
# 以下を実施しています
#
# (1) terraform plan / apply 差分ありの結果を整形
# (2) terraform plan / apply 失敗の一覧を整形
#

# (1) terraform plan / apply 差分ありの結果を整形
TF_CHANGE_RESULT="$TF_LOG_DIR/change_result" # 整形した内容を格納するファイル

if [ -s $TF_CHANGE_LIST ]; then # 差分があるときのみ実行する

    # 差分ありのテーブルのヘッダー
    cat <<TABLE_HEADER > "$TF_CHANGE_RESULT"
<table>
    <tr>
        <td>:file_folder: <b>Path</b></td>
        <td>:white_check_mark: <b>Add</b></td>
        <td>:warning: <b>Change</b></td>
        <td>:bangbang: <b>Destroy</b></td>
        <td>:blue_book: <b>詳細</b></td>
    </tr>
TABLE_HEADER

    # 各ログファイルの一列目は出力が混じらないようにつけているパス名があるので削除
    # 詳細は terraform_wrapper.sh の add_target_name 関数参照
    for f in $(cat $TF_CHANGE_LIST)
    do
        cut -d ":" -f 2- "$f" > "$f.new"
    done

    # *.new ファイルの合計文字数を調べる
    total_character_count=$(cat ./*.new | wc -m)

    # 文字数が GitHub Comment の限界を超えている場合は detail を非表示にします
    [ $total_character_count -gt $((MAX_GITHUB_ISSUE_BODY_CHARACTER_COUNT - COMMENT_METADATA_CHARACTER_COUNT)) ] && ENABLE_DETAIL_TRUNCATE=true

    # 各差分ファイルの内容を参照し、表形式に整形する
    for f in $(cat $TF_CHANGE_LIST)
    do

        # 実行した terraform state の名前をログ名から取得
        path_name=$(echo $f | sed -e 's@_terraform\.log@@g' -e 's@_@/@g')

        # 例: Plan: 0 to add, 2 to change, 0 to destroy. のような出力から
        # それぞれの値を取り出す。ただし 0 の場合は見栄え上 - にする
        read add_count change_count destroy_count <<< $(grep -i "${TF_TYPE}.*add.*change.*destroy" $f.new \
            | sed -e "s/ 0 / - /g" \
            | sed -re "s/.*: ([-0-9]*)[^-0-9]*([-0-9]*)[^-0-9]*([-0-9]*)[^-0-9]*/\1 \2 \3/g")

        # 差分ありのテーブルのボディー
        if [ $ENABLE_DETAIL_TRUNCATE = "true" ]; then
            detail="行数が多いため削除"
        else
            detail="
<details><summary>Terraform 実行結果 (Click me)</summary>

\`\`\`
$(cat "$f.new")

\`\`\`

</details>"
        fi

        cat <<TABLE_BODY
<tr>
    <td><b>$path_name</b></td>
    <td align="center"><b>$add_count</b></td>
    <td align="center"><b>$change_count</b></td>
    <td align="center"><b>$destroy_count</b></td>
    <td align="left">$detail</td>
</tr>
TABLE_BODY

    done >> "$TF_CHANGE_RESULT"
    echo "</table>" >> "$TF_CHANGE_RESULT"
else
    # 差分が存在しない場合
    echo "なし" > $TF_CHANGE_RESULT
fi

# (2) terraform plan / apply 失敗の一覧を整形
TF_FAIL_RESULT="$TF_LOG_DIR/fail_result"

if [[ ${TF_FAIL_LIST[0]} = "" ]]; then
    # 失敗なし
    echo "なし" > "$TF_FAIL_RESULT"
else
    # 失敗あり
    # ファイル名を整形して一覧に書き込む
    echo ${TF_FAIL_LIST[@]} | xargs -n 1 -I{} | sed -e 's@_terraform_fail\.log@@g' -e 's@_@/@g' -e 's@^@- @g' >> "$TF_FAIL_RESULT"
fi

# Slack にコメント通知する GitHub Action の対象にするかどうかのフラグです
# この値が true の場合に GitHub に投稿されたコメントは Slack に通知されます
[ "${SLACK_FLAG:-false}" = "true" ] && PRE_COMMENT="[post slack]" || PRE_COMMENT=""

# GitHub に投稿する文言を整形する
GITHUB_COMMENT_FORMAT="${PRE_COMMENT}
## :rocket: Terraform ${TF_TYPE} ( PJ: ${PROJECT_ID} / 環境: ${STAGE} ) <sup>[ビルド結果](${BUILD_URL})</sup>

### ${TF_TYPE} に失敗したステート

$(cat "$TF_FAIL_RESULT")

### 差分があるステート

$(cat "$TF_CHANGE_RESULT")

### 差分がないステート

<details><summary>一覧を見る (Click me)</summary>

$(cat $TF_NOCHANGE_LIST | sed -e "s@_terraform\.log@@g" -e "s@_@/@g")

</details>

"

#
# 3. コメントを出力する
#

echo "$GITHUB_COMMENT_FORMAT"

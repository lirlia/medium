#!/bin/bash
# 指定のビルドIDより前に実行された、各種条件にヒットする Cloud Build ジョブのビルドIDを取得します

set -o pipefail
set -o nounset
set -o errexit

CMDNAME=${0##*/}

function prefail() { echo "$@" 1>&2; usage; exit 1; }
function usage() {
    cat <<USAGE >&2
Usage:
    $CMDNAME [OPTIONS]

Options
    --build_id [BUILD_ID]                           検索対象に使うジョブ
    --check_trigger_name_regex [TRIGGER_NAME_REGEX] ビルドトリガー名の検索時に使用する正規表現です
    --limit num                                     検索数の上限です
    --disable_on_going                              通常は実行中のジョブのみを対象にしますが、
                                                    このフラグが付与されているときはすべてのジョブを対象にします。
    --region [REGION_NAME]                          Private Pool 利用時はリージョンを指定してください
    --help / -h
USAGE
}

LIMIT=10                    # Cloudbuild のジョブを検索する数です
BUILD_ID=dummy              # 検索の起点となるジョブIDです。このジョブより前に作成されたものをチェックします
TRIGGER_NAME_REGEX=dummy    # 検索対象とするジョブを実行したトリガー名です
ONGOING_FLAG=true           # ongoing(現在実行中)のジョブのみを対象にする場合は true にしてください
REGION=""                   # worker pool で利用する場合必要です

# Process arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
    --build_id)
        BUILD_ID="$2"
        shift 2
        ;;
    --check_trigger_name_regex)
        TRIGGER_NAME_REGEX="$2"
        shift 2
        ;;
    --limit)
        LIMIT="$2"
        shift 2
        ;;
    --disable_on_going)
        ONGOING_FLAG="false"
        shift 1
        ;;
    --region)
        REGION="--region $2"
        shift 2
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

# 条件にマッチしたジョブの一覧を返却します
function getOngoingJobListBeforeSpecificJob() {

    local build_start_time=$(gcloud builds describe $BUILD_ID --format='value(startTime)' $REGION)
    local args=(
        # ジョブ作成順にソート
        --sort-by=create_time
        # 検索数
        --limit "${LIMIT}"
        # ビルドIDを取得
        --format="value(ID)"
        # 検索のフィルターです
        --filter="id!=$BUILD_ID \
                    AND startTime<=$build_start_time\
                    AND substitutions.TRIGGER_NAME~$TRIGGER_NAME_REGEX"
        # worker pool で使うリージョンです
        $REGION
    )
    [ $ONGOING_FLAG = true ] && args+=(--ongoing)

    # 実行中のジョブのビルドID一覧を取得
    gcloud builds list "${args[@]}"
}

getOngoingJobListBeforeSpecificJob

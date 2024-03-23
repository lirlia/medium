# Firebase Remote Config を Git 管理する GitHub Actions を作った

こんにちは。MIXI 開発本部 SREグループの [riddle](https://twitter.com/riddle_tec) です。

Firebase Remote Config を Git 管理したい！と思ったので GitHub Actions を作りました。

## Feature Flag 開発とは

Feature Flag 開発とは、アプリケーションの機能をリリース時に ON/OFF するための仕組みです。
たとえば新機能をリリースする際に、まずは一部のユーザーにだけ公開してみたり、リリース後に問題が発生した場合にすぐに機能を OFF にできます。

Firebase Remote Config は Feature Flag 開発時によく使われるツールです。

## Feature Flag の管理方法の課題

Firebase Remote Config の設定追加・変更は Web UI と API、SDK から行うことができます。

Web UI は、直感的に設定を行うことができますが人間が操作するため手間もかかりますし、複数の環境に設定することを考えると間違える可能性もあります。また調べた限りでは SDK や API をラップした便利に使えそうなツールが見当たりませんでした。(2024/03/23 時点)

そこで Firebase Remote Config の設定を Git 管理し GitHub Actions で自動的に設定を行う仕組みを作りました。

[lirlia/firebase-remote-config-actions: This is a GitHub Actions workflow to add or update Firebase Remote Config](https://github.com/lirlia/firebase-remote-config-actions)

これにより 2 つのメリットがあります。

1. Remote Config の更新を宣言的に行える
2. 設定の構文チェックや差分を確認できる

では、実際にどのように使うのか見ていきましょう。

## 使い方

Firebase Remote Config を書き換えるため事前に Google Cloud の権限を Workload Identity 経由で取得し、`lirlia/firebase-remote-config-actions` を呼び出すだけです。

```yaml
name: Manage Firebase Remote Config
on: [push]
jobs:
  firebase-remote-config:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: google-github-actions/auth@v2
        with:
          project_id: YOUR_PROJECT_ID
          workload_identity_provider: YOUR_PROVIDER
          # this flag must be set to true to create the credentials file
          # firebase actions require GOOGLE_APPLICATION_CREDENTIALS to be set
          create_credentials_file: true

      - name: Validate Firebase Remote Config
        uses: lirlia/firebase-remote-config-actions@main
        with:
          command: 'validate'
          # Please specify the absolute path.
          template-file-path: '${{ github.workspace }}/template.json'
          service-account-email: 'xxx@yyyy.iam.gserviceaccount.com'
```

このツールには3つのコマンドがあるので CI/CD に組み込むことができます。

- validate: テンプレートファイルの構文チェックを行います。
- diff: ローカルのテンプレートファイルとリモートの設定を比較します。
- publish: テンプレートファイルをリモートに反映します。

たとえば diff を使うと、PR が作成された際に、リモートの設定との差分を確認できます。

```diff
 {
   parameterGroups: {
     Feature Flags: {
       parameters: {
+        featureFlagA: {
+          defaultValue: {
+            value: "false"
+          }
+          conditionalValues: {
+            ios-1.0.0: {
+              value: "true"
+            }
+            android-1.0.0: {
+              value: "true"
+            }
+          }
+          valueType: "BOOLEAN"
+        }
         featureFlagB: {
-          conditionalValues: {
-            ios-0.1.0: {
-              value: "true"
-            }
-            android-0.1.0: {
-              value: "true"
-            }
-          }
           defaultValue: {
-            value: "false"
+            value: "true"
           }
         }
       }
     }
   }
   conditions: [
     {
-      name: "ios-0.1.0"
+      name: "ios-1.0.0"
-      expression: "app.id == 'xx' && app.version.>=(['0.1.0'])"
+      expression: "app.id == 'xx' && app.version.>=(['1.0.0'])"
     }
     {
-      name: "android-0.1.0"
+      name: "android-1.0.0"
-      expression: "app.id == 'xx' && app.version.>=(['0.1.0'])"
+      expression: "app.id == 'xx' && app.version.>=(['1.0.0'])"
     }
   ]
 }
```

## 実際に使っている例

自分が所属するチームでは、Git リポジトリにて `remote_config_環境名.json` を管理しています。そして、このファイルの変更をトリガーにして CI/CD で Firebase Remote Config を更新しています。 

ディレクトリレイアウト

```
- .github
  - actions
    - remote-config
      - action.yaml
  - workflows
    - check_remote_config.yaml
    - publish_remote_config.yaml
- remote_config_production.json
- remote_config_staging.json
```

### `check_remote_config.yaml`

PR が作成された際に、`remote_config_環境名.json` の validate と diff を行います。

```yaml
name: check remote config

on:
  pull_request:
    branches:
      - main
      - staging
    paths:
      - remote_config_staging.json
      - remote_config_production.json
      - .github/workflows/check-remote-config.yaml

permissions:
  contents: read
  id-token: write
  pull-requests: write

jobs:
  check_remote_config:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - id: staging
        if: github.base_ref == 'staging'
        uses: ./.github/actions/remote-config
        with:
          project_id: XXXXXXX
          workload_identity_provider: projects/XXXXXXX/locations/global/workloadIdentityPools/pool/providers/github
          service_account_email: remote-config-updater@XXXXXXX.iam.gserviceaccount.com
          remote_config_path: ${{ github.workspace }}/remote_config_staging.json
          command: check

      - id: production
        if: github.base_ref == 'main'
        uses: ./.github/actions/remote-config
        with:
          project_id: XXXXXXX
          workload_identity_provider: projects/XXXXXXX/locations/global/workloadIdentityPools/pool/providers/github
          service_account_email: remote-config-updater@XXXXXXX.iam.gserviceaccount.com
          remote_config_path: ${{ github.workspace }}/remote_config_production.json
          command: check
```

### `publish_remote_config.yaml`

main または staging ブランチに push された際に、`remote_config_環境名.json` を Firebase Remote Config に反映します。

```yaml
name: publish remote config

on:
  push:
    branches:
      - main
      - staging
    paths:
      - remote_config_staging.json
      - remote_config_production.json

permissions:
  contents: read
  id-token: write

jobs:
  check_remote_config:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - id: staging
        if: github.ref_name == 'staging'
        uses: ./.github/actions/remote-config
        with:
          project_id: XXXXXXX
          workload_identity_provider: projects/XXXXXXX/locations/global/workloadIdentityPools/pool/providers/github
          service_account_email: remote-config-updater@XXXXXXX.iam.gserviceaccount.com
          remote_config_path: ${{ github.workspace }}/remote_config_staging.json
          command: publish

      - id: production
        if: github.ref_name == 'main'
        uses: ./.github/actions/remote-config
        with:
          project_id: XXXXXXX
          workload_identity_provider: projects/XXXXXXX/locations/global/workloadIdentityPools/pool/providers/github
          service_account_email: remote-config-updater@XXXXXXX.iam.gserviceaccount.com
          remote_config_path: ${{ github.workspace }}/remote_config_production.json
          command: publish
```

### `action.yaml`

`check_remote_config.yaml` と `publish_remote_config.yaml` で使用する GitHub Actions の定義ファイルです。ほぼ同じ内容ですが、`command` によって処理を分岐しています。

```yaml
name: "remote config"
description: execute remote config for firebase
inputs:
  project_id:
    description: GCP Project ID
    required: true

  workload_identity_provider:
    description: workload identity provider
    required: true

  service_account_email:
    description: service account email
    required: true

  remote_config_path:
    description: remote config path
    required: true

  command:
    description: command(check/publish)
    required: true
    default: "validate"

outputs:
  diff:
    description: result(only for check command)
    value: ${{ steps.diff.outputs.diff }}

  is_valid:
    description: result
    value: ${{ steps.validate.outputs.is_valid }}

  invalid-reason:
    description: result(only for is_valid is false)
    value: ${{ steps.validate.outputs.invalid-reason }}

runs:
  using: "composite"
  steps:
    - uses: google-github-actions/auth@v2
      with:
        project_id: ${{ inputs.project_id }}
        workload_identity_provider: ${{ inputs.workload_identity_provider }}
        create_credentials_file: true

    - id: validate
      uses: lirlia/firebase-remote-config-actions@v0.0.1
      with:
        command: validate
        template-file-path: ${{ inputs.remote_config_path }}
        service-account-email: ${{ inputs.service_account_email }}

    - name: check validate is ok
      shell: bash
      run: |
        if [ "${{ steps.validate.outputs.is_valid }}" == "false" ]; then
          echo "Remote config validation failed"
          echo "${{ steps.validate.outputs.invalid-reason }}"
          exit 1
        fi

    - id: diff
      uses: lirlia/firebase-remote-config-actions@v0.0.1
      if: ${{ inputs.command == 'check' }}
      with:
        command: diff
        template-file-path: ${{ inputs.remote_config_path }}
        service-account-email: ${{ inputs.service_account_email }}

    - uses: lirlia/firebase-remote-config-actions@v0.0.1
      if: ${{ inputs.command == 'publish' }}
      with:
        command: publish
        template-file-path: ${{ inputs.remote_config_path }}
        service-account-email: ${{ inputs.service_account_email }}

    - name: Comment PR
      uses: thollander/actions-comment-pull-request@v2
      if: ${{ inputs.command == 'check' && steps.diff.outputs.diff != '' }}
      with:
        message: |
          ## Remote Config Diff

          ```diff
          ${{ steps.diff.outputs.diff }}
          ```

        comment_tag: execution
```

## まとめ

Firebase Remote Config 用の json を Git 管理することで事前に構文チェックと diff を行うことができ、リリース時のミスを防ぐことができます。またリリース自体も GitHub Actions で自動化することで、運用コストを下げつつ宣言的に設定を行うことができます。

ぜひお試しください。

[lirlia/firebase-remote-config-actions: This is a GitHub Actions workflow to add or update Firebase Remote Config](https://github.com/lirlia/firebase-remote-config-actions)

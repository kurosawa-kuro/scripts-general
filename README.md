# scripts-general

汎用的なAWS/Kubernetes操作スクリプト集

## Quick Start

```bash
# ヘルプ表示
make help

# 環境チェック
make env-check

# チートシート
make cheat
```

## Directory Structure

```
scripts-general/
├── aws/          # AWS操作 (ECR, Lambda, Secrets, SQS, SNS, etc.)
├── k8s/          # Kubernetes操作 (kind, EKS, Helm, Ingress, Secrets)
├── setup/        # セットアップ (Node, Go, Python, Terraform, etc.)
├── ops/          # 運用ツール (コスト確認, ヘルスチェック, バックアップ)
├── dev/          # 開発ユーティリティ (ポート管理, Docker)
├── lib/          # 共通ライブラリ
├── cheat.sh      # コマンドチートシート
└── Makefile      # メインエントリポイント
```

---

## Setup - 開発環境セットアップ

| Command | Description |
|---------|-------------|
| `make setup-node` | Node.js (nvm経由) インストール |
| `make setup-go VERSION=x.x.x` | Go インストール |
| `make setup-python VERSION=3.x.x` | Python (pyenv経由) インストール |
| `make setup-terraform VERSION=x.x.x` | Terraform インストール |
| `make setup-aws-cli` | AWS CLI v2 インストール |
| `make setup-rust` | Rust (rustup経由) インストール |
| `make setup-kubectl` | kubectl インストール |
| `make setup-helm` | Helm インストール |
| `make setup-kind` | kind (K8s in Docker) インストール |
| `make setup-buildx` | Docker buildx セットアップ |
| `make setup-claude` | Claude Code CLI インストール |
| `make setup-github` | GitHub SSH キー設定 |
| `make setup-portainer` | Portainer (Docker UI) セットアップ |
| `make env-check` | 開発環境チェック |

---

## AWS - Amazon Web Services

### Profile & ECR

| Command | Description |
|---------|-------------|
| `make aws-profile` | AWS プロファイル表示/切替 |
| `make ecr-login` | ECR ログイン |
| `make ecr-create REPO=name` | ECR リポジトリ作成 |
| `make ecr-show REPO=name` | ECR リポジトリ表示 |
| `make ecr-list` | 全ECR リポジトリ一覧 |

### Lambda

| Command | Description |
|---------|-------------|
| `make lambda-create NAME=fn` | Lambda 関数作成 |
| `make lambda-create NAME=fn ZIP=code.zip` | ZIP から作成 |
| `make lambda-show NAME=fn` | Lambda 関数詳細 |
| `make lambda-list` | 全Lambda 関数一覧 |
| `make lambda-invoke NAME=fn PAYLOAD='{}'` | Lambda 実行 |
| `make lambda-logs NAME=fn` | Lambda ログ表示 |

### Secrets Manager

| Command | Description |
|---------|-------------|
| `make secrets-create NAME=secret VALUE=val` | シークレット作成 |
| `make secrets-show NAME=secret` | シークレット詳細 |
| `make secrets-show NAME=secret VALUE=1` | 値も表示 |
| `make secrets-list` | 全シークレット一覧 |
| `make secrets-delete NAME=secret` | シークレット削除 |

### SQS (Simple Queue Service)

| Command | Description |
|---------|-------------|
| `make sqs-create NAME=queue` | SQS キュー作成 |
| `make sqs-create NAME=queue FIFO=1` | FIFO キュー作成 |
| `make sqs-show NAME=queue` | キュー詳細 |
| `make sqs-list` | 全キュー一覧 |

### SNS (Simple Notification Service)

| Command | Description |
|---------|-------------|
| `make sns-create NAME=topic` | SNS トピック作成 |
| `make sns-show NAME=topic` | トピック詳細 |
| `make sns-list` | 全トピック一覧 |

### Cognito & Storage

| Command | Description |
|---------|-------------|
| `make cognito-create POOL=name` | Cognito User Pool 作成 |
| `make cognito-show POOL=name` | Cognito User Pool 表示 |
| `make s3-create BUCKET=name` | S3 バケット作成 |
| `make s3-show BUCKET=name` | S3 バケット表示 |
| `make dynamodb-create TABLE=name` | DynamoDB テーブル作成 |
| `make dynamodb-show TABLE=name` | DynamoDB テーブル表示 |
| `make firehose-create STREAM=n BUCKET=b` | Firehose → S3 作成 |

### Parameter Store

| Command | Description |
|---------|-------------|
| `make param-get NAME=/path` | パラメータ取得 |
| `make param-list PATH=/` | パラメータ一覧 |
| `make param-set NAME=/path VALUE=val` | パラメータ設定 |
| `make param-set-secure NAME=/path VALUE=val` | SecureString 設定 |

---

## Kubernetes

### kind (Local Cluster)

| Command | Description |
|---------|-------------|
| `make kind-create CLUSTER=kind` | kind クラスタ作成 |
| `make kind-delete CLUSTER=kind` | kind クラスタ削除 |
| `make kind-delete-all` | 全kind クラスタ削除 |

### EKS

| Command | Description |
|---------|-------------|
| `make eks-config CLUSTER=name` | EKS kubeconfig セットアップ |

### Helm

| Command | Description |
|---------|-------------|
| `make helm-repo-common` | 共通リポジトリ追加 |
| `make helm-install RELEASE=r CHART=repo/chart` | チャートインストール |
| `make helm-list` | リリース一覧 |
| `make helm-show RELEASE=r` | リリース詳細 |
| `make helm-uninstall RELEASE=r` | アンインストール |

### Secrets

| Command | Description |
|---------|-------------|
| `make k8s-secret-create NAME=s KEYS="k=v k2=v2"` | Secret 作成 |
| `make k8s-secret-show NAME=s DECODE=1` | Secret 表示 (デコード) |
| `make k8s-secret-list` | Secret 一覧 |

### Ingress

| Command | Description |
|---------|-------------|
| `make ingress-create NAME=i HOST=h SERVICE=s PORT=p` | Ingress 作成 |
| `make ingress-show NAME=i` | Ingress 詳細 |
| `make ingress-list` | Ingress 一覧 |

---

## Operations - 運用ツール

### Cost Management

| Command | Description |
|---------|-------------|
| `make aws-cost` | AWS 月間コスト概要 |
| `make aws-cost-daily` | 日別コスト |
| `make aws-cost-services` | サービス別コスト |
| `make aws-cost-forecast` | コスト予測 |

### Monitoring & Health

| Command | Description |
|---------|-------------|
| `make health-check URL=https://...` | URL ヘルスチェック |
| `make health-check K8S=1` | Kubernetes クラスタチェック |
| `make health-check AWS=1` | AWS サービスチェック |

### Backup & Cleanup

| Command | Description |
|---------|-------------|
| `make backup-s3 SOURCE=./data BUCKET=b` | S3 へバックアップ |
| `make cleanup-ecr REPO=r KEEP=10` | ECR 古いイメージ削除 |

---

## Development Utilities

| Command | Description |
|---------|-------------|
| `make ports-show` | 開発ポート表示 (3000-3999, 5000-5999, 8000-8999) |
| `make ports-kill` | 全開発ポートプロセス停止 |
| `make docker-kill` | 全Docker コンテナ停止 |

---

## Git Config

| Command | Description |
|---------|-------------|
| `make git-switch` | Git 設定プロファイル切替 |
| `make git-list` | Git 設定プロファイル一覧 |
| `make git-add PROFILE=name` | 新規プロファイル追加 |

---

## Cheatsheet - コマンド集

| Command | Description |
|---------|-------------|
| `make cheat` | カテゴリ一覧 |
| `make cheat-docker` | Docker コマンド集 |
| `make cheat-k8s` | Kubernetes コマンド集 |
| `make cheat-helm` | Helm コマンド集 |
| `make cheat-git` | Git コマンド集 |
| `make cheat-aws` | AWS コマンド集 |
| `make cheat-terraform` | Terraform コマンド集 |
| `make cheat-linux` | Linux コマンド集 |

```bash
# 検索も可能
./cheat.sh "port forward"
```

---

## Library Functions

スクリプト内で共通関数を使用可能:

```bash
source "$SCRIPT_DIR/lib/core.sh"
source "$SCRIPT_DIR/lib/aws.sh"
source "$SCRIPT_DIR/lib/k8s.sh"
```

### core.sh
- `print_header`, `print_section`, `print_success`, `print_error`, `print_warning`, `print_info`
- `require_command`, `require_aws_cli`, `require_jq`, `require_curl`
- `confirm`, `mask_password`, `json_get`, `json_create`

### aws.sh
- S3: `s3_create_bucket`, `s3_bucket_exists`, `s3_upload_string`
- DynamoDB: `dynamodb_create_table`, `dynamodb_put_item`
- Lambda: `lambda_create`, `lambda_invoke`, `lambda_get_logs`
- Secrets: `secrets_create`, `secrets_get`, `secrets_update`
- SQS: `sqs_create_queue`, `sqs_send_message`, `sqs_receive_message`
- SNS: `sns_create_topic`, `sns_publish`, `sns_subscribe`
- ECR: `ecr_create_repo`, `ecr_docker_login`, `ecr_list_images`
- SSM: `ssm_get_param`, `ssm_put_param`

### k8s.sh
- Context: `k8s_get_current_context`, `k8s_set_context`
- kind: `kind_create_cluster`, `kind_delete_cluster`, `kind_load_image`
- EKS: `eks_update_kubeconfig`, `eks_get_cluster_info`
- Helm: `helm_install`, `helm_upgrade`, `helm_uninstall`, `helm_repo_add`
- Secrets: `k8s_secret_create_generic`, `k8s_secret_get_value`
- Ingress: `k8s_ingress_exists`, `k8s_ingress_list`

---

## Requirements

- Bash 4.0+
- make
- 各ツールは必要に応じて (`make env-check` で確認)

## License

MIT

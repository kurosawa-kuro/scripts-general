# scripts-general

汎用的なAWS/Kubernetes操作スクリプト集

## Quick Start

```bash
# ヘルプ表示
make help

# 環境チェック
make env-check
```

## Directory Structure

```
scripts-general/
├── aws/          # AWS操作スクリプト (ECR, Cognito, S3, DynamoDB, etc.)
├── dev/          # 開発ユーティリティ (ポート管理, Docker等)
├── k8s/          # Kubernetes操作 (kind, EKS)
├── lib/          # 共通ライブラリ
├── setup/        # セットアップスクリプト
├── cheat.sh      # コマンドチートシート
└── Makefile      # メインエントリポイント
```

## Commands

### Setup - Development Environment

| Command | Description |
|---------|-------------|
| `make setup-node` | Node.js (nvm経由) インストール |
| `make setup-go` | Go インストール (VERSION=x.x.x 指定可) |
| `make setup-claude` | Claude Code CLI インストール |
| `make setup-github` | GitHub SSH キー設定 |
| `make setup-portainer` | Portainer (Docker UI) セットアップ |
| `make env-check` | 開発環境チェック |
| `make env-check-all` | 全ツールチェック (オプション含む) |

### AWS - Profile & ECR

| Command | Description |
|---------|-------------|
| `make aws-profile` | AWS プロファイル表示/切替 |
| `make aws-profile-list` | AWS プロファイル一覧 |
| `make ecr-login` | ECR ログイン |
| `make ecr-create REPO=name` | ECR リポジトリ作成 |
| `make ecr-show REPO=name` | ECR リポジトリ表示 |
| `make ecr-list` | 全ECR リポジトリ一覧 |

### AWS - Cognito & Storage

| Command | Description |
|---------|-------------|
| `make cognito-create POOL=name` | Cognito User Pool 作成 |
| `make cognito-show POOL=name` | Cognito User Pool 表示 |
| `make s3-create BUCKET=name` | S3 バケット作成 |
| `make s3-show BUCKET=name` | S3 バケット表示 |
| `make s3-list` | 全S3 バケット一覧 |
| `make dynamodb-create TABLE=name` | DynamoDB テーブル作成 |
| `make dynamodb-show TABLE=name` | DynamoDB テーブル表示 |
| `make dynamodb-list` | 全DynamoDB テーブル一覧 |
| `make firehose-create STREAM=name BUCKET=name` | Firehose → S3 作成 |
| `make firehose-show STREAM=name` | Firehose ストリーム表示 |
| `make firehose-list` | 全Firehose ストリーム一覧 |

### AWS - Parameter Store

| Command | Description |
|---------|-------------|
| `make param-get NAME=/path` | パラメータ取得 |
| `make param-list PATH=/` | パラメータ一覧 |
| `make param-set NAME=/path VALUE=value` | パラメータ設定 |
| `make param-set-secure NAME=/path VALUE=value` | SecureString 設定 |
| `make param-delete NAME=/path` | パラメータ削除 |

### Kubernetes

| Command | Description |
|---------|-------------|
| `make kind-create CLUSTER=kind` | kind クラスタ作成 |
| `make kind-delete CLUSTER=kind` | kind クラスタ削除 |
| `make kind-delete-all` | 全kind クラスタ削除 |
| `make eks-config CLUSTER=name` | EKS kubeconfig セットアップ |

### Git Config

| Command | Description |
|---------|-------------|
| `make git-switch` | Git 設定プロファイル表示/切替 |
| `make git-list` | Git 設定プロファイル一覧 |
| `make git-add PROFILE=name` | 新規プロファイル追加 |

### Development Utilities

| Command | Description |
|---------|-------------|
| `make ports-show` | 開発ポート表示 (3000-3999, 5000-5999, 8000-8999) |
| `make ports-kill` | 全開発ポートプロセス停止 |
| `make docker-kill` | 全Docker コンテナ停止 |

### Cheatsheet

| Command | Description |
|---------|-------------|
| `make cheat` | コマンドチートシート表示 |
| `make cheat-docker` | Docker コマンド集 |
| `make cheat-k8s` | Kubernetes コマンド集 |
| `make cheat-git` | Git コマンド集 |
| `make cheat-aws` | AWS コマンド集 |
| `make cheat-linux` | Linux コマンド集 |

## Requirements

- Bash 4.0+
- make
- 各ツール (AWS CLI, kubectl, Docker, etc.) は必要に応じて

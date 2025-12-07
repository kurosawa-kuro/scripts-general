# =============================================================================
# scripts-general Makefile
# =============================================================================
# Usage: make help
# =============================================================================

.PHONY: help

# Default target
help: ## Show this help
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'
	@echo ""

# =============================================================================
# Setup - Development Environment
# =============================================================================

setup-node: ## Install Node.js via nvm
	@bash setup/nodejs-install.sh

setup-go: ## Install Go (latest or VERSION=x.x.x)
	@bash setup/go-install.sh $(VERSION)

setup-claude: ## Install Claude Code CLI
	@bash setup/claude-install.sh

setup-github: ## Setup GitHub SSH key
	@bash setup/github-ssh.sh

setup-portainer: ## Setup Portainer (Docker UI)
	@bash setup/portainer-install.sh

setup-python: ## Install Python via pyenv (VERSION=3.x.x)
	@bash setup/python-install.sh $(VERSION)

setup-terraform: ## Install Terraform (VERSION=x.x.x)
	@bash setup/terraform-install.sh $(VERSION)

setup-aws-cli: ## Install AWS CLI v2
	@bash setup/aws-cli-install.sh

setup-rust: ## Install Rust via rustup
	@bash setup/rust-install.sh

setup-kubectl: ## Install kubectl
	@bash setup/kubectl-install.sh $(VERSION)

setup-helm: ## Install Helm
	@bash setup/helm-install.sh

setup-kind: ## Install kind (K8s in Docker)
	@bash setup/kind-install.sh

setup-buildx: ## Setup Docker buildx
	@bash setup/docker-buildx.sh $(NAME)

env-check: ## Check development environment
	@bash setup/env-check.sh

env-check-all: ## Check all tools (including optional)
	@bash setup/env-check.sh --all

# =============================================================================
# AWS - Profile & Config
# =============================================================================

aws-profile: ## Show/switch AWS profile
	@bash aws/profile-switch.sh

aws-profile-list: ## List AWS profiles
	@bash aws/profile-switch.sh --list

# =============================================================================
# AWS - ECR (Container Registry)
# =============================================================================

ecr-login: ## Login to ECR
	@bash aws/ecr-login.sh

ecr-create: ## Create ECR repository (REPO=name)
	@bash aws/ecr-create.sh $(REPO)

ecr-show: ## Show ECR repository (REPO=name)
	@bash aws/ecr-show.sh $(REPO)

ecr-list: ## List all ECR repositories
	@bash aws/ecr-show.sh --list

# =============================================================================
# AWS - Cognito
# =============================================================================

cognito-create: ## Create Cognito User Pool (POOL=name)
	@bash aws/cognito-create.sh $(POOL)

cognito-show: ## Show Cognito User Pool (POOL=name)
	@bash aws/cognito-show.sh $(POOL)

# =============================================================================
# AWS - S3 & DynamoDB
# =============================================================================

s3-create: ## Create S3 bucket (BUCKET=name)
	@bash aws/s3-create.sh $(BUCKET)

s3-show: ## Show S3 bucket (BUCKET=name)
	@bash aws/s3-show.sh $(BUCKET)

s3-list: ## List all S3 buckets
	@bash aws/s3-show.sh --list

dynamodb-create: ## Create DynamoDB table (TABLE=name)
	@bash aws/dynamodb-create.sh $(TABLE)

dynamodb-show: ## Show DynamoDB table (TABLE=name)
	@bash aws/dynamodb-show.sh $(TABLE)

dynamodb-list: ## List all DynamoDB tables
	@bash aws/dynamodb-show.sh --list

firehose-create: ## Create Firehose to S3 (STREAM=name BUCKET=name)
	@bash aws/firehose-create.sh $(STREAM) $(BUCKET)

firehose-show: ## Show Firehose stream (STREAM=name)
	@bash aws/firehose-show.sh $(STREAM)

firehose-list: ## List all Firehose streams
	@bash aws/firehose-show.sh --list

# =============================================================================
# AWS - Lambda
# =============================================================================

lambda-create: ## Create Lambda function (NAME=name [ZIP=file.zip])
	@bash aws/lambda-create.sh $(NAME) $(ZIP)

lambda-show: ## Show Lambda function (NAME=name)
	@bash aws/lambda-show.sh $(NAME)

lambda-list: ## List all Lambda functions
	@bash aws/lambda-show.sh --list

lambda-invoke: ## Invoke Lambda function (NAME=name [PAYLOAD='{}'])
	@aws lambda invoke --function-name $(NAME) --payload '$(PAYLOAD)' /tmp/lambda-out.json && cat /tmp/lambda-out.json

lambda-logs: ## Show Lambda logs (NAME=name)
	@aws logs tail /aws/lambda/$(NAME) --since 1h

# =============================================================================
# AWS - Secrets Manager
# =============================================================================

secrets-create: ## Create secret (NAME=name VALUE=value)
	@bash aws/secrets-create.sh $(NAME) "$(VALUE)"

secrets-show: ## Show secret metadata (NAME=name [VALUE=1 to show value])
	@bash aws/secrets-show.sh $(NAME) $(if $(VALUE),--value,)

secrets-list: ## List all secrets
	@bash aws/secrets-show.sh --list

secrets-delete: ## Delete secret (NAME=name [FORCE=1])
	@bash aws/secrets-create.sh --delete $(NAME) $(if $(FORCE),true,)

# =============================================================================
# AWS - SQS (Simple Queue Service)
# =============================================================================

sqs-create: ## Create SQS queue (NAME=name [--fifo])
	@bash aws/sqs-create.sh $(NAME) $(if $(FIFO),--fifo,)

sqs-show: ## Show SQS queue details (NAME=name)
	@bash aws/sqs-show.sh $(NAME)

sqs-list: ## List all SQS queues
	@bash aws/sqs-show.sh --list

# =============================================================================
# AWS - SNS (Simple Notification Service)
# =============================================================================

sns-create: ## Create SNS topic (NAME=name)
	@bash aws/sns-create.sh $(NAME)

sns-show: ## Show SNS topic details (NAME=name)
	@bash aws/sns-show.sh $(NAME)

sns-list: ## List all SNS topics
	@bash aws/sns-show.sh --list

# =============================================================================
# AWS - Parameter Store
# =============================================================================

param-get: ## Get parameter (NAME=/path/to/param)
	@bash aws/param-get.sh $(NAME)

param-list: ## List parameters (PATH=/)
	@bash aws/param-get.sh --list $(PATH)

param-set: ## Set parameter (NAME=/path VALUE=value [TYPE=String|SecureString])
	@bash aws/param-set.sh $(NAME) "$(VALUE)" $(if $(TYPE),--type $(TYPE),)

param-set-secure: ## Set SecureString parameter (NAME=/path VALUE=value)
	@bash aws/param-set.sh $(NAME) "$(VALUE)" --secure

param-delete: ## Delete parameter (NAME=/path/to/param)
	@bash aws/param-set.sh $(NAME) --delete

# =============================================================================
# Kubernetes - kind (Local)
# =============================================================================

kind-create: ## Create kind cluster (CLUSTER=kind)
	@bash k8s/kind-create.sh $(CLUSTER)

kind-delete: ## Delete kind cluster (CLUSTER=kind)
	@bash k8s/kind-delete.sh $(CLUSTER)

kind-delete-all: ## Delete all kind clusters
	@bash k8s/kind-delete.sh --all --force

# =============================================================================
# Kubernetes - EKS
# =============================================================================

eks-config: ## Setup EKS kubeconfig (CLUSTER=name)
	@bash k8s/eks-config.sh $(CLUSTER)

# =============================================================================
# Kubernetes - Helm
# =============================================================================

helm-repo: ## Manage Helm repos (add NAME URL / --common / --list)
	@bash k8s/helm-repo.sh $(CMD) $(NAME) $(URL)

helm-repo-common: ## Add common Helm repos
	@bash k8s/helm-repo.sh --common

helm-install: ## Install Helm chart (RELEASE=name CHART=repo/chart [-n NS])
	@bash k8s/helm-install.sh $(RELEASE) $(CHART) $(if $(NAMESPACE),-n $(NAMESPACE),)

helm-list: ## List Helm releases
	@bash k8s/helm-list.sh $(if $(NAMESPACE),-n $(NAMESPACE),)

helm-show: ## Show Helm release (RELEASE=name)
	@bash k8s/helm-list.sh $(RELEASE) $(if $(NAMESPACE),-n $(NAMESPACE),)

helm-uninstall: ## Uninstall Helm release (RELEASE=name)
	@bash k8s/helm-uninstall.sh $(RELEASE) $(if $(NAMESPACE),-n $(NAMESPACE),)

# =============================================================================
# Kubernetes - Secrets
# =============================================================================

k8s-secret-create: ## Create K8s secret (NAME=name KEY=val [KEY=val...])
	@bash k8s/secret-create.sh $(NAME) $(KEYS) $(if $(NAMESPACE),-n $(NAMESPACE),)

k8s-secret-show: ## Show K8s secret (NAME=name [--decode])
	@bash k8s/secret-show.sh $(NAME) $(if $(DECODE),--decode,) $(if $(NAMESPACE),-n $(NAMESPACE),)

k8s-secret-list: ## List K8s secrets
	@bash k8s/secret-show.sh --list $(if $(NAMESPACE),-n $(NAMESPACE),)

# =============================================================================
# Kubernetes - Ingress
# =============================================================================

ingress-create: ## Create Ingress (NAME=name HOST=host SERVICE=svc PORT=port)
	@bash k8s/ingress-create.sh $(NAME) --host $(HOST) --service $(SERVICE) --port $(PORT) $(if $(NAMESPACE),-n $(NAMESPACE),)

ingress-show: ## Show Ingress (NAME=name)
	@bash k8s/ingress-show.sh $(NAME) $(if $(NAMESPACE),-n $(NAMESPACE),)

ingress-list: ## List Ingresses
	@bash k8s/ingress-show.sh --list $(if $(NAMESPACE),-n $(NAMESPACE),)

# =============================================================================
# Git Config
# =============================================================================

git-switch: ## Show/switch git config profile
	@bash setup/git-switch.sh

git-list: ## List git config profiles
	@bash setup/git-switch.sh --list

git-add: ## Add new git config profile (PROFILE=name)
	@bash setup/git-switch.sh --add $(PROFILE)

# =============================================================================
# Development - Ports & Docker
# =============================================================================

ports-show: ## Show dev ports (3000-3999, 5000-5999, 8000-8999)
	@bash dev/ports-show.sh

ports-kill: ## Kill all dev port processes
	@bash dev/ports-kill.sh

docker-kill: ## Kill all docker containers
	@bash dev/docker-kill.sh

# =============================================================================
# Operations - Cost & Monitoring
# =============================================================================

aws-cost: ## Show AWS cost summary
	@bash ops/aws-cost.sh

aws-cost-daily: ## Show AWS daily costs
	@bash ops/aws-cost.sh --daily

aws-cost-services: ## Show AWS cost by service
	@bash ops/aws-cost.sh --services

aws-cost-forecast: ## Show AWS cost forecast
	@bash ops/aws-cost.sh --forecast

health-check: ## Check endpoints health (URL=... or --k8s/--aws)
	@bash ops/health-check.sh $(URL) $(if $(K8S),--k8s,) $(if $(AWS),--aws,)

backup-s3: ## Backup to S3 (SOURCE=path BUCKET=name [PREFIX=backups])
	@bash ops/backup-s3.sh $(SOURCE) $(BUCKET) $(PREFIX)

cleanup-ecr: ## Clean old ECR images (REPO=name [KEEP=10])
	@bash ops/cleanup-ecr.sh $(REPO) $(if $(KEEP),--keep $(KEEP),)

# =============================================================================
# Utilities
# =============================================================================

cheat: ## Show command cheatsheet
	@bash cheat.sh

cheat-docker: ## Show docker cheatsheet
	@bash cheat.sh docker

cheat-k8s: ## Show kubernetes cheatsheet
	@bash cheat.sh k8s

cheat-git: ## Show git cheatsheet
	@bash cheat.sh git

cheat-aws: ## Show aws cheatsheet
	@bash cheat.sh aws

cheat-linux: ## Show linux cheatsheet
	@bash cheat.sh linux

cheat-helm: ## Show helm cheatsheet
	@bash cheat.sh helm

cheat-terraform: ## Show terraform cheatsheet
	@bash cheat.sh terraform

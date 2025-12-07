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

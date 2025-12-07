#!/bin/bash
# =============================================================================
# Command Cheatsheet
# =============================================================================
#
# This script:
# 1. Displays commonly used commands by category
# 2. Supports search/filter
# 3. Quick reference for frequently forgotten commands
#
# Usage:
#   ./cheatsheet.sh [CATEGORY]
#   ./cheatsheet.sh [SEARCH_TERM]
#
# Examples:
#   ./cheatsheet.sh          # Show all categories
#   ./cheatsheet.sh docker   # Show docker commands
#   ./cheatsheet.sh k8s      # Show kubernetes commands
#   ./cheatsheet.sh "port"   # Search for "port"
#
# Categories: docker, k8s, git, aws, linux, all
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load libraries
source "$SCRIPT_DIR/lib/core.sh"

# =============================================================================
# Cheatsheet Data
# =============================================================================

show_docker() {
    print_section "Docker"
    cat <<'EOF'
  # Containers
  docker ps                         # List running containers
  docker ps -a                      # List all containers
  docker stop $(docker ps -q)       # Stop all containers
  docker rm $(docker ps -aq)        # Remove all containers
  docker logs -f <container>        # Follow container logs

  # Images
  docker images                     # List images
  docker rmi <image>                # Remove image
  docker image prune -a             # Remove unused images
  docker build -t <name> .          # Build image

  # Volumes & Networks
  docker volume ls                  # List volumes
  docker volume prune               # Remove unused volumes
  docker network ls                 # List networks

  # Compose
  docker compose up -d              # Start services
  docker compose down               # Stop services
  docker compose logs -f            # Follow all logs
  docker compose ps                 # List services

  # Cleanup
  docker system prune -a            # Remove all unused data
  docker system df                  # Show disk usage
EOF
}

show_k8s() {
    print_section "Kubernetes"
    cat <<'EOF'
  # Context & Config
  kubectl config get-contexts       # List contexts
  kubectl config use-context <ctx>  # Switch context
  kubectl config current-context    # Show current context

  # Get Resources
  kubectl get pods                  # List pods
  kubectl get pods -A               # All namespaces
  kubectl get svc                   # List services
  kubectl get deploy                # List deployments
  kubectl get all                   # List all resources
  kubectl get nodes -o wide         # List nodes with details

  # Describe & Logs
  kubectl describe pod <pod>        # Pod details
  kubectl logs <pod>                # Pod logs
  kubectl logs -f <pod>             # Follow logs
  kubectl logs <pod> -c <container> # Specific container

  # Execute & Debug
  kubectl exec -it <pod> -- bash    # Shell into pod
  kubectl port-forward <pod> 8080:80 # Port forward
  kubectl top pods                  # Resource usage

  # Apply & Delete
  kubectl apply -f <file.yaml>      # Apply manifest
  kubectl delete -f <file.yaml>     # Delete manifest
  kubectl delete pod <pod>          # Delete pod

  # Rollout
  kubectl rollout status deploy/<d> # Deployment status
  kubectl rollout restart deploy/<d> # Restart deployment
  kubectl rollout undo deploy/<d>   # Rollback
EOF
}

show_git() {
    print_section "Git"
    cat <<'EOF'
  # Status & Diff
  git status                        # Working tree status
  git diff                          # Unstaged changes
  git diff --staged                 # Staged changes
  git log --oneline -10             # Last 10 commits

  # Branches
  git branch                        # List branches
  git branch -a                     # All branches
  git checkout -b <branch>          # Create & switch
  git branch -d <branch>            # Delete branch
  git switch <branch>               # Switch branch (new)

  # Commit & Push
  git add .                         # Stage all
  git commit -m "message"           # Commit
  git commit --amend                # Amend last commit
  git push -u origin <branch>       # Push new branch

  # Merge & Rebase
  git merge <branch>                # Merge branch
  git rebase <branch>               # Rebase onto branch
  git rebase -i HEAD~3              # Interactive rebase

  # Undo & Reset
  git checkout -- <file>            # Discard changes
  git reset HEAD <file>             # Unstage file
  git reset --soft HEAD~1           # Undo commit (keep changes)
  git reset --hard HEAD~1           # Undo commit (lose changes)
  git stash                         # Stash changes
  git stash pop                     # Apply stash

  # Remote
  git remote -v                     # List remotes
  git fetch --all                   # Fetch all remotes
  git pull --rebase                 # Pull with rebase
EOF
}

show_aws() {
    print_section "AWS CLI"
    cat <<'EOF'
  # Identity
  aws sts get-caller-identity       # Current identity
  aws configure list                # Show config
  aws configure                     # Configure AWS CLI

  # S3
  aws s3 ls                         # List buckets
  aws s3 ls s3://bucket/            # List objects
  aws s3 cp file s3://bucket/       # Upload file
  aws s3 sync . s3://bucket/        # Sync directory
  aws s3 rm s3://bucket/key         # Delete object

  # EC2
  aws ec2 describe-instances        # List instances
  aws ec2 start-instances --instance-ids <id>
  aws ec2 stop-instances --instance-ids <id>

  # ECS/EKS
  aws ecs list-clusters             # List ECS clusters
  aws eks list-clusters             # List EKS clusters
  aws eks update-kubeconfig --name <cluster>

  # ECR
  aws ecr get-login-password | docker login --username AWS --password-stdin <registry>
  aws ecr describe-repositories     # List repositories
  aws ecr describe-images --repository-name <repo>

  # Lambda
  aws lambda list-functions         # List functions
  aws lambda invoke --function-name <fn> out.txt

  # CloudWatch
  aws logs describe-log-groups      # List log groups
  aws logs tail /aws/lambda/<fn>    # Tail logs
EOF
}

show_helm() {
    print_section "Helm"
    cat <<'EOF'
  # Repository
  helm repo add <name> <url>        # Add repo
  helm repo update                  # Update repos
  helm repo list                    # List repos
  helm search repo <keyword>        # Search charts

  # Install & Upgrade
  helm install <release> <chart>    # Install chart
  helm install <rel> <chart> -n <ns> # With namespace
  helm install <rel> <chart> -f values.yaml
  helm upgrade <rel> <chart>        # Upgrade release
  helm upgrade --install <rel> <chart> # Install or upgrade

  # List & Status
  helm list                         # List releases
  helm list -A                      # All namespaces
  helm status <release>             # Release status
  helm history <release>            # Release history

  # Get Info
  helm get values <release>         # Get values
  helm get manifest <release>       # Get manifest
  helm show values <chart>          # Show chart values

  # Delete
  helm uninstall <release>          # Uninstall release
  helm uninstall <release> -n <ns>  # With namespace

  # Debug
  helm template <rel> <chart>       # Render templates
  helm lint <chart>                 # Lint chart
  helm install --dry-run --debug <rel> <chart>
EOF
}

show_terraform() {
    print_section "Terraform"
    cat <<'EOF'
  # Initialize
  terraform init                    # Initialize directory
  terraform init -upgrade           # Upgrade providers
  terraform providers               # List providers

  # Plan & Apply
  terraform plan                    # Preview changes
  terraform plan -out=plan.tfplan   # Save plan
  terraform apply                   # Apply changes
  terraform apply plan.tfplan       # Apply saved plan
  terraform apply -auto-approve     # Skip confirmation

  # State
  terraform state list              # List resources
  terraform state show <resource>   # Show resource
  terraform state mv <src> <dst>    # Move resource
  terraform state rm <resource>     # Remove from state
  terraform import <res> <id>       # Import resource

  # Destroy
  terraform destroy                 # Destroy all
  terraform destroy -target=<res>   # Destroy specific

  # Workspace
  terraform workspace list          # List workspaces
  terraform workspace new <name>    # Create workspace
  terraform workspace select <name> # Switch workspace

  # Format & Validate
  terraform fmt                     # Format files
  terraform fmt -recursive          # Format all
  terraform validate                # Validate config

  # Output
  terraform output                  # Show outputs
  terraform output -json            # JSON format
  terraform console                 # Interactive console
EOF
}

show_linux() {
    print_section "Linux/Shell"
    cat <<'EOF'
  # Files & Directories
  ls -la                            # List with details
  find . -name "*.txt"              # Find files
  grep -r "pattern" .               # Search in files
  du -sh *                          # Directory sizes
  df -h                             # Disk usage

  # Process
  ps aux                            # All processes
  ps aux | grep <name>              # Find process
  kill -9 <pid>                     # Force kill
  top                               # Process monitor
  htop                              # Better process monitor

  # Network
  netstat -tulpn                    # Listening ports
  ss -tulpn                         # Listening ports (modern)
  lsof -i :8080                     # Process on port
  curl -I <url>                     # HTTP headers
  curl -X POST -d '{}' <url>        # POST request

  # System
  free -h                           # Memory usage
  uptime                            # System uptime
  uname -a                          # System info
  cat /etc/os-release               # OS info

  # Archive
  tar -czvf archive.tar.gz dir/     # Create tar.gz
  tar -xzvf archive.tar.gz          # Extract tar.gz
  zip -r archive.zip dir/           # Create zip
  unzip archive.zip                 # Extract zip

  # SSH
  ssh user@host                     # Connect
  ssh -L 8080:localhost:80 user@host # Port forward
  scp file user@host:/path/         # Copy file
  ssh-keygen -t ed25519             # Generate key
EOF
}

show_all() {
    show_docker
    echo ""
    show_k8s
    echo ""
    show_helm
    echo ""
    show_git
    echo ""
    show_aws
    echo ""
    show_terraform
    echo ""
    show_linux
}

show_categories() {
    echo ""
    echo "Available categories:"
    echo ""
    echo -e "  ${CYAN}docker${NC}     - Docker & Compose commands"
    echo -e "  ${CYAN}k8s${NC}        - Kubernetes commands"
    echo -e "  ${CYAN}helm${NC}       - Helm package manager"
    echo -e "  ${CYAN}git${NC}        - Git commands"
    echo -e "  ${CYAN}aws${NC}        - AWS CLI commands"
    echo -e "  ${CYAN}terraform${NC}  - Terraform IaC"
    echo -e "  ${CYAN}linux${NC}      - Linux/Shell commands"
    echo -e "  ${CYAN}all${NC}        - Show all categories"
    echo ""
    echo "Usage: $0 [CATEGORY|SEARCH_TERM]"
}

search_commands() {
    local term="$1"

    print_section "Search Results: $term"

    # Capture all output and search
    local results=$(
        show_all 2>/dev/null | grep -i --color=never "$term" | head -20
    )

    if [ -z "$results" ]; then
        print_warning "No results found for: $term"
    else
        echo "$results" | sed 's/^/  /'
    fi
}

# =============================================================================
# Main
# =============================================================================

main() {
    local category="${1:-}"

    print_header "Command Cheatsheet"

    case "$category" in
        docker)
            show_docker
            ;;
        k8s|kubernetes|kube)
            show_k8s
            ;;
        helm)
            show_helm
            ;;
        git)
            show_git
            ;;
        aws)
            show_aws
            ;;
        terraform|tf)
            show_terraform
            ;;
        linux|shell|bash)
            show_linux
            ;;
        all)
            show_all
            ;;
        "")
            show_categories
            ;;
        --help|-h)
            show_categories
            ;;
        *)
            # Treat as search term
            search_commands "$category"
            ;;
    esac
}

main "$@"

#!/bin/bash
# =============================================================================
# Kubernetes Library for scripts-general
# =============================================================================
# Kubernetes/kind/EKS utilities
#
# Usage:
#   source "$SCRIPT_DIR/../lib/core.sh"
#   source "$SCRIPT_DIR/../lib/k8s.sh"
# =============================================================================

# Prevent multiple sourcing
[[ -n "${_K8S_SH_LOADED:-}" ]] && return 0
_K8S_SH_LOADED=1

# Ensure core is loaded
[[ -z "${_CORE_SH_LOADED:-}" ]] && echo "Error: core.sh must be loaded first" && exit 1

# =============================================================================
# Requirement Checks
# =============================================================================

require_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed"
        print_info "Install: https://kubernetes.io/docs/tasks/tools/install-kubectl/"
        return 1
    fi
    return 0
}

require_kind() {
    if ! command -v kind &> /dev/null; then
        print_error "kind is not installed"
        print_info "Install: https://kind.sigs.k8s.io/docs/user/quick-start/#installation"
        return 1
    fi
    return 0
}

require_helm() {
    if ! command -v helm &> /dev/null; then
        print_error "helm is not installed"
        print_info "Install: https://helm.sh/docs/intro/install/"
        return 1
    fi
    return 0
}

# =============================================================================
# Context Functions
# =============================================================================

k8s_get_current_context() {
    kubectl config current-context 2>/dev/null
}

k8s_context_exists() {
    local context_name="$1"
    kubectl config get-contexts "$context_name" &>/dev/null
}

k8s_set_context() {
    local context_name="$1"

    if ! k8s_context_exists "$context_name"; then
        print_error "Context '$context_name' does not exist"
        return 1
    fi

    kubectl config use-context "$context_name" &>/dev/null
}

k8s_list_contexts() {
    kubectl config get-contexts -o name 2>/dev/null
}

# =============================================================================
# Namespace Functions
# =============================================================================

k8s_namespace_exists() {
    local namespace="$1"
    kubectl get namespace "$namespace" &>/dev/null
}

k8s_create_namespace() {
    local namespace="$1"

    if k8s_namespace_exists "$namespace"; then
        print_debug "Namespace '$namespace' already exists"
        return 0
    fi

    kubectl create namespace "$namespace" &>/dev/null
}

# =============================================================================
# Kind Functions
# =============================================================================

kind_cluster_exists() {
    local cluster_name="${1:-kind}"
    kind get clusters 2>/dev/null | grep -q "^${cluster_name}$"
}

kind_create_cluster() {
    local cluster_name="${1:-kind}"
    local config_file="${2:-}"
    local image="${3:-}"

    print_info "Creating kind cluster: $cluster_name"

    local cmd="kind create cluster --name $cluster_name"

    if [ -n "$config_file" ] && [ -f "$config_file" ]; then
        cmd="$cmd --config $config_file"
    fi

    if [ -n "$image" ]; then
        cmd="$cmd --image $image"
    fi

    eval "$cmd" 2>&1
}

kind_delete_cluster() {
    local cluster_name="${1:-kind}"

    print_info "Deleting kind cluster: $cluster_name"
    kind delete cluster --name "$cluster_name" 2>&1
}

kind_get_kubeconfig() {
    local cluster_name="${1:-kind}"
    kind get kubeconfig --name "$cluster_name" 2>/dev/null
}

kind_load_image() {
    local image_name="$1"
    local cluster_name="${2:-kind}"

    print_info "Loading image '$image_name' into cluster '$cluster_name'"
    kind load docker-image "$image_name" --name "$cluster_name" 2>&1
}

# =============================================================================
# EKS Functions
# =============================================================================

eks_cluster_exists() {
    local cluster_name="$1"
    local region="${2:-$(aws_get_region)}"

    aws eks describe-cluster --name "$cluster_name" --region "$region" &>/dev/null
}

eks_update_kubeconfig() {
    local cluster_name="$1"
    local region="${2:-$(aws_get_region)}"
    local profile="${3:-}"

    print_info "Updating kubeconfig for EKS cluster: $cluster_name"

    local cmd="aws eks update-kubeconfig --name $cluster_name --region $region"

    if [ -n "$profile" ]; then
        cmd="$cmd --profile $profile"
    fi

    eval "$cmd" 2>&1
}

eks_get_cluster_info() {
    local cluster_name="$1"
    local region="${2:-$(aws_get_region)}"

    aws eks describe-cluster --name "$cluster_name" --region "$region" --output json 2>/dev/null
}

eks_list_clusters() {
    local region="${1:-$(aws_get_region)}"

    aws eks list-clusters --region "$region" --query 'clusters[]' --output text 2>/dev/null
}

# =============================================================================
# Cluster Verification Functions
# =============================================================================

k8s_check_connection() {
    kubectl cluster-info &>/dev/null
}

k8s_get_nodes() {
    kubectl get nodes -o wide 2>/dev/null
}

k8s_wait_nodes_ready() {
    local timeout="${1:-120}"
    local interval=5
    local waited=0

    print_info "Waiting for nodes to be ready..."

    while [ $waited -lt $timeout ]; do
        local not_ready=$(kubectl get nodes --no-headers 2>/dev/null | grep -v " Ready " | wc -l)

        if [ "$not_ready" -eq 0 ]; then
            local node_count=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
            if [ "$node_count" -gt 0 ]; then
                print_success "All $node_count node(s) are ready"
                return 0
            fi
        fi

        print_debug "Waiting for nodes... ($waited/$timeout seconds)"
        sleep $interval
        waited=$((waited + interval))
    done

    print_warning "Timeout waiting for nodes to be ready"
    return 1
}

# =============================================================================
# Resource Functions
# =============================================================================

k8s_apply_manifest() {
    local manifest="$1"
    local namespace="${2:-}"

    local cmd="kubectl apply -f $manifest"
    if [ -n "$namespace" ]; then
        cmd="$cmd -n $namespace"
    fi

    eval "$cmd" 2>&1
}

k8s_delete_resource() {
    local resource_type="$1"
    local resource_name="$2"
    local namespace="${3:-}"

    local cmd="kubectl delete $resource_type $resource_name"
    if [ -n "$namespace" ]; then
        cmd="$cmd -n $namespace"
    fi

    eval "$cmd" 2>&1
}

k8s_get_pods() {
    local namespace="${1:-}"

    if [ -n "$namespace" ]; then
        kubectl get pods -n "$namespace" -o wide 2>/dev/null
    else
        kubectl get pods --all-namespaces -o wide 2>/dev/null
    fi
}

k8s_wait_deployment() {
    local deployment_name="$1"
    local namespace="${2:-default}"
    local timeout="${3:-120}"

    print_info "Waiting for deployment '$deployment_name' to be ready..."
    kubectl rollout status deployment/"$deployment_name" -n "$namespace" --timeout="${timeout}s" 2>&1
}

# =============================================================================
# Helm Functions
# =============================================================================

helm_repo_exists() {
    local repo_name="$1"
    helm repo list 2>/dev/null | grep -q "^${repo_name}\s"
}

helm_repo_add() {
    local repo_name="$1"
    local repo_url="$2"

    if helm_repo_exists "$repo_name"; then
        print_info "Repo '$repo_name' already exists, updating..."
        helm repo update "$repo_name" 2>/dev/null
        return 0
    fi

    print_info "Adding Helm repo: $repo_name"
    helm repo add "$repo_name" "$repo_url" 2>/dev/null
    helm repo update "$repo_name" 2>/dev/null
}

helm_repo_list() {
    helm repo list 2>/dev/null
}

helm_release_exists() {
    local release_name="$1"
    local namespace="${2:-default}"

    helm list -n "$namespace" 2>/dev/null | grep -q "^${release_name}\s"
}

helm_install() {
    local release_name="$1"
    local chart="$2"
    local namespace="${3:-default}"
    local values_file="${4:-}"

    print_info "Installing Helm release: $release_name"

    local cmd="helm install $release_name $chart -n $namespace --create-namespace"

    if [ -n "$values_file" ] && [ -f "$values_file" ]; then
        cmd="$cmd -f $values_file"
    fi

    eval "$cmd" 2>&1
}

helm_upgrade() {
    local release_name="$1"
    local chart="$2"
    local namespace="${3:-default}"
    local values_file="${4:-}"

    print_info "Upgrading Helm release: $release_name"

    local cmd="helm upgrade $release_name $chart -n $namespace --install"

    if [ -n "$values_file" ] && [ -f "$values_file" ]; then
        cmd="$cmd -f $values_file"
    fi

    eval "$cmd" 2>&1
}

helm_uninstall() {
    local release_name="$1"
    local namespace="${2:-default}"

    print_info "Uninstalling Helm release: $release_name"
    helm uninstall "$release_name" -n "$namespace" 2>&1
}

helm_list() {
    local namespace="${1:-}"

    if [ -n "$namespace" ]; then
        helm list -n "$namespace" 2>/dev/null
    else
        helm list -A 2>/dev/null
    fi
}

helm_get_values() {
    local release_name="$1"
    local namespace="${2:-default}"

    helm get values "$release_name" -n "$namespace" 2>/dev/null
}

helm_get_status() {
    local release_name="$1"
    local namespace="${2:-default}"

    helm status "$release_name" -n "$namespace" 2>/dev/null
}

# =============================================================================
# Secret Functions
# =============================================================================

k8s_secret_exists() {
    local secret_name="$1"
    local namespace="${2:-default}"

    kubectl get secret "$secret_name" -n "$namespace" &>/dev/null
}

k8s_secret_create_generic() {
    local secret_name="$1"
    local namespace="${2:-default}"
    shift 2
    local literals=("$@")

    print_info "Creating secret: $secret_name"

    local cmd="kubectl create secret generic $secret_name -n $namespace"
    for lit in "${literals[@]}"; do
        cmd="$cmd --from-literal=$lit"
    done

    eval "$cmd" 2>&1
}

k8s_secret_create_from_file() {
    local secret_name="$1"
    local namespace="${2:-default}"
    local file_path="$3"
    local key="${4:-$(basename "$file_path")}"

    print_info "Creating secret from file: $secret_name"

    kubectl create secret generic "$secret_name" -n "$namespace" --from-file="$key=$file_path" 2>&1
}

k8s_secret_create_tls() {
    local secret_name="$1"
    local namespace="${2:-default}"
    local cert_file="$3"
    local key_file="$4"

    print_info "Creating TLS secret: $secret_name"

    kubectl create secret tls "$secret_name" -n "$namespace" --cert="$cert_file" --key="$key_file" 2>&1
}

k8s_secret_get() {
    local secret_name="$1"
    local namespace="${2:-default}"

    kubectl get secret "$secret_name" -n "$namespace" -o json 2>/dev/null
}

k8s_secret_get_value() {
    local secret_name="$1"
    local key="$2"
    local namespace="${3:-default}"

    kubectl get secret "$secret_name" -n "$namespace" -o jsonpath="{.data.$key}" 2>/dev/null | base64 -d
}

k8s_secret_list() {
    local namespace="${1:-}"

    if [ -n "$namespace" ]; then
        kubectl get secrets -n "$namespace" 2>/dev/null
    else
        kubectl get secrets -A 2>/dev/null
    fi
}

k8s_secret_delete() {
    local secret_name="$1"
    local namespace="${2:-default}"

    print_info "Deleting secret: $secret_name"
    kubectl delete secret "$secret_name" -n "$namespace" 2>&1
}

# =============================================================================
# Ingress Functions
# =============================================================================

k8s_ingress_exists() {
    local ingress_name="$1"
    local namespace="${2:-default}"

    kubectl get ingress "$ingress_name" -n "$namespace" &>/dev/null
}

k8s_ingress_list() {
    local namespace="${1:-}"

    if [ -n "$namespace" ]; then
        kubectl get ingress -n "$namespace" 2>/dev/null
    else
        kubectl get ingress -A 2>/dev/null
    fi
}

k8s_ingress_get() {
    local ingress_name="$1"
    local namespace="${2:-default}"

    kubectl get ingress "$ingress_name" -n "$namespace" -o json 2>/dev/null
}

k8s_ingress_describe() {
    local ingress_name="$1"
    local namespace="${2:-default}"

    kubectl describe ingress "$ingress_name" -n "$namespace" 2>/dev/null
}

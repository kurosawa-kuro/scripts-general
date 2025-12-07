#!/bin/bash
# =============================================================================
# AWS Library for scripts-general
# =============================================================================
# AWS-specific utilities
#
# Usage:
#   source "$SCRIPT_DIR/../lib/core.sh"
#   source "$SCRIPT_DIR/../lib/aws.sh"
# =============================================================================

# Prevent multiple sourcing
[[ -n "${_AWS_SH_LOADED:-}" ]] && return 0
_AWS_SH_LOADED=1

# Ensure core is loaded
[[ -z "${_CORE_SH_LOADED:-}" ]] && echo "Error: core.sh must be loaded first" && exit 1

# =============================================================================
# S3 Functions
# =============================================================================

s3_bucket_exists() {
    local bucket="$1"
    aws s3api head-bucket --bucket "$bucket" 2>/dev/null
}

s3_create_bucket() {
    local bucket="$1"
    local region="${2:-$(aws_get_region)}"

    print_info "Creating S3 bucket: $bucket"

    if [ "$region" = "us-east-1" ]; then
        aws s3api create-bucket --bucket "$bucket" --region "$region" --output json > /dev/null
    else
        aws s3api create-bucket --bucket "$bucket" --region "$region" \
            --create-bucket-configuration LocationConstraint="$region" --output json > /dev/null
    fi
}

s3_block_public_access() {
    local bucket="$1"
    aws s3api put-public-access-block --bucket "$bucket" \
        --public-access-block-configuration \
        "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" 2>/dev/null
}

s3_enable_versioning() {
    local bucket="$1"
    aws s3api put-bucket-versioning --bucket "$bucket" \
        --versioning-configuration Status=Enabled 2>/dev/null
}

s3_upload_string() {
    local bucket="$1"
    local key="$2"
    local content="$3"
    local content_type="${4:-text/plain}"

    echo "$content" | aws s3 cp - "s3://$bucket/$key" --content-type "$content_type" 2>/dev/null
}

# =============================================================================
# DynamoDB Functions
# =============================================================================

dynamodb_table_exists() {
    local table="$1"
    local region="${2:-$(aws_get_region)}"

    aws dynamodb describe-table --table-name "$table" --region "$region" --output json 2>/dev/null
}

dynamodb_create_table() {
    local table="$1"
    local pk_name="${2:-id}"
    local pk_type="${3:-N}"
    local region="${4:-$(aws_get_region)}"
    local rcu="${5:-5}"
    local wcu="${6:-5}"

    print_info "Creating DynamoDB table: $table"

    aws dynamodb create-table \
        --table-name "$table" \
        --attribute-definitions "AttributeName=$pk_name,AttributeType=$pk_type" \
        --key-schema "AttributeName=$pk_name,KeyType=HASH" \
        --provisioned-throughput "ReadCapacityUnits=$rcu,WriteCapacityUnits=$wcu" \
        --region "$region" \
        --output json 2>/dev/null
}

dynamodb_wait_active() {
    local table="$1"
    local region="${2:-$(aws_get_region)}"

    print_info "Waiting for table to become active..."
    aws dynamodb wait table-exists --table-name "$table" --region "$region"
}

dynamodb_put_item() {
    local table="$1"
    local item="$2"
    local region="${3:-$(aws_get_region)}"

    aws dynamodb put-item --table-name "$table" --item "$item" --region "$region" --output json 2>/dev/null
}

dynamodb_scan_count() {
    local table="$1"
    local region="${2:-$(aws_get_region)}"

    aws dynamodb scan --table-name "$table" --region "$region" --select COUNT --output json 2>/dev/null | jq -r '.Count'
}

# =============================================================================
# Cognito Functions
# =============================================================================

cognito_get_pool_id() {
    local pool_name="$1"
    local region="${2:-$(aws_get_region)}"

    aws cognito-idp list-user-pools --max-results 60 --region "$region" \
        --query "UserPools[?Name=='$pool_name'].Id | [0]" --output text 2>/dev/null | grep -v "^None$"
}

cognito_create_user_pool() {
    local pool_name="$1"
    local region="${2:-$(aws_get_region)}"

    print_info "Creating Cognito User Pool: $pool_name"

    aws cognito-idp create-user-pool \
        --pool-name "$pool_name" \
        --region "$region" \
        --auto-verified-attributes email \
        --username-attributes email \
        --policies '{
            "PasswordPolicy": {
                "MinimumLength": 8,
                "RequireUppercase": true,
                "RequireLowercase": true,
                "RequireNumbers": true,
                "RequireSymbols": false
            }
        }' \
        --admin-create-user-config '{"AllowAdminCreateUserOnly": false}' \
        --output json 2>/dev/null
}

cognito_get_client_id() {
    local pool_id="$1"
    local client_name="$2"
    local region="${3:-$(aws_get_region)}"

    aws cognito-idp list-user-pool-clients --user-pool-id "$pool_id" --region "$region" \
        --query "UserPoolClients[?ClientName=='$client_name'].ClientId | [0]" --output text 2>/dev/null | grep -v "^None$"
}

cognito_create_app_client() {
    local pool_id="$1"
    local client_name="$2"
    local region="${3:-$(aws_get_region)}"

    print_info "Creating App Client: $client_name"

    aws cognito-idp create-user-pool-client \
        --user-pool-id "$pool_id" \
        --client-name "$client_name" \
        --region "$region" \
        --no-generate-secret \
        --explicit-auth-flows "ALLOW_USER_PASSWORD_AUTH" "ALLOW_REFRESH_TOKEN_AUTH" "ALLOW_USER_SRP_AUTH" \
        --output json 2>/dev/null
}

cognito_user_exists() {
    local pool_id="$1"
    local username="$2"
    local region="${3:-$(aws_get_region)}"

    aws cognito-idp admin-get-user --user-pool-id "$pool_id" --username "$username" --region "$region" &>/dev/null
}

cognito_create_user() {
    local pool_id="$1"
    local email="$2"
    local password="$3"
    local region="${4:-$(aws_get_region)}"

    print_info "Creating test user: $email"

    aws cognito-idp admin-create-user \
        --user-pool-id "$pool_id" \
        --username "$email" \
        --user-attributes "Name=email,Value=$email" "Name=email_verified,Value=true" \
        --message-action SUPPRESS \
        --region "$region" \
        --output json 2>/dev/null

    aws cognito-idp admin-set-user-password \
        --user-pool-id "$pool_id" \
        --username "$email" \
        --password "$password" \
        --permanent \
        --region "$region" 2>/dev/null
}

cognito_auth() {
    local client_id="$1"
    local username="$2"
    local password="$3"
    local region="${4:-$(aws_get_region)}"

    aws cognito-idp initiate-auth \
        --auth-flow USER_PASSWORD_AUTH \
        --client-id "$client_id" \
        --auth-parameters "USERNAME=$username,PASSWORD=$password" \
        --region "$region" \
        --output json 2>&1
}

# =============================================================================
# Firehose Functions
# =============================================================================

firehose_exists() {
    local stream_name="$1"
    local region="${2:-$(aws_get_region)}"

    aws firehose describe-delivery-stream --delivery-stream-name "$stream_name" --region "$region" &>/dev/null
}

firehose_create() {
    local stream_name="$1"
    local bucket_name="$2"
    local role_arn="$3"
    local region="${4:-$(aws_get_region)}"
    local buffer_size="${5:-5}"
    local buffer_interval="${6:-300}"

    print_info "Creating Firehose: $stream_name"

    local s3_config=$(cat <<EOF
{
    "RoleARN": "$role_arn",
    "BucketARN": "arn:aws:s3:::$bucket_name",
    "Prefix": "data/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/",
    "ErrorOutputPrefix": "errors/!{firehose:error-output-type}/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/",
    "BufferingHints": {"SizeInMBs": $buffer_size, "IntervalInSeconds": $buffer_interval},
    "CompressionFormat": "GZIP",
    "CloudWatchLoggingOptions": {"Enabled": false}
}
EOF
)

    aws firehose create-delivery-stream \
        --delivery-stream-name "$stream_name" \
        --delivery-stream-type "DirectPut" \
        --extended-s3-destination-configuration "$s3_config" \
        --region "$region" \
        --output json 2>/dev/null
}

firehose_wait_active() {
    local stream_name="$1"
    local region="${2:-$(aws_get_region)}"
    local max_wait="${3:-120}"
    local interval=10
    local waited=0

    print_info "Waiting for Firehose to become active..."

    while [ $waited -lt $max_wait ]; do
        local status=$(aws firehose describe-delivery-stream \
            --delivery-stream-name "$stream_name" --region "$region" \
            --query 'DeliveryStreamDescription.DeliveryStreamStatus' --output text 2>/dev/null)

        [[ "$status" == "ACTIVE" ]] && return 0

        print_debug "Status: $status"
        sleep $interval
        waited=$((waited + interval))
    done
    return 1
}

firehose_put_record() {
    local stream_name="$1"
    local data="$2"
    local region="${3:-$(aws_get_region)}"

    local encoded=$(echo -n "$data" | base64 -w 0)

    aws firehose put-record \
        --delivery-stream-name "$stream_name" \
        --record "Data=$encoded" \
        --region "$region" \
        --output json 2>/dev/null
}

# =============================================================================
# IAM Functions
# =============================================================================

iam_role_exists() {
    local role_name="$1"
    aws iam get-role --role-name "$role_name" &>/dev/null
}

iam_get_role_arn() {
    local role_name="$1"
    aws iam get-role --role-name "$role_name" --query 'Role.Arn' --output text 2>/dev/null
}

iam_create_firehose_role() {
    local role_name="$1"
    local bucket_name="$2"
    local account_id="$3"

    print_info "Creating IAM role: $role_name"

    local trust_policy=$(cat <<EOF
{
    "Version": "2012-10-17",
    "Statement": [{
        "Effect": "Allow",
        "Principal": {"Service": "firehose.amazonaws.com"},
        "Action": "sts:AssumeRole",
        "Condition": {"StringEquals": {"sts:ExternalId": "$account_id"}}
    }]
}
EOF
)

    aws iam create-role --role-name "$role_name" --assume-role-policy-document "$trust_policy" --output json >/dev/null 2>&1

    local s3_policy=$(cat <<EOF
{
    "Version": "2012-10-17",
    "Statement": [{
        "Effect": "Allow",
        "Action": ["s3:AbortMultipartUpload","s3:GetBucketLocation","s3:GetObject","s3:ListBucket","s3:ListBucketMultipartUploads","s3:PutObject"],
        "Resource": ["arn:aws:s3:::$bucket_name","arn:aws:s3:::$bucket_name/*"]
    }]
}
EOF
)

    local policy_name="${role_name}-policy"
    local policy_arn=$(aws iam create-policy --policy-name "$policy_name" --policy-document "$s3_policy" --query 'Policy.Arn' --output text 2>/dev/null)

    [[ -z "$policy_arn" ]] && policy_arn="arn:aws:iam::${account_id}:policy/${policy_name}"

    aws iam attach-role-policy --role-name "$role_name" --policy-arn "$policy_arn" 2>/dev/null

    print_info "Waiting for IAM role propagation (10s)..."
    sleep 10
}

# =============================================================================
# ECR Functions
# =============================================================================

ecr_repo_exists() {
    local repo_name="$1"
    local region="${2:-$(aws_get_region)}"

    aws ecr describe-repositories --repository-names "$repo_name" --region "$region" &>/dev/null
}

ecr_create_repo() {
    local repo_name="$1"
    local region="${2:-$(aws_get_region)}"
    local scan_on_push="${3:-true}"
    local tag_mutability="${4:-MUTABLE}"

    print_info "Creating ECR repository: $repo_name"

    aws ecr create-repository \
        --repository-name "$repo_name" \
        --region "$region" \
        --image-scanning-configuration "scanOnPush=$scan_on_push" \
        --image-tag-mutability "$tag_mutability" \
        --output json 2>/dev/null
}

ecr_get_login_password() {
    local region="${1:-$(aws_get_region)}"

    aws ecr get-login-password --region "$region" 2>/dev/null
}

ecr_get_registry_url() {
    local account_id="${1:-$(aws_get_account_id)}"
    local region="${2:-$(aws_get_region)}"

    echo "${account_id}.dkr.ecr.${region}.amazonaws.com"
}

ecr_list_images() {
    local repo_name="$1"
    local region="${2:-$(aws_get_region)}"

    aws ecr describe-images \
        --repository-name "$repo_name" \
        --region "$region" \
        --query 'imageDetails[*].{Tags:imageTags[0],Size:imageSizeInBytes,Pushed:imagePushedAt,Digest:imageDigest}' \
        --output json 2>/dev/null
}

ecr_get_repo_info() {
    local repo_name="$1"
    local region="${2:-$(aws_get_region)}"

    aws ecr describe-repositories \
        --repository-names "$repo_name" \
        --region "$region" \
        --output json 2>/dev/null
}

ecr_docker_login() {
    local region="${1:-$(aws_get_region)}"
    local account_id="${2:-$(aws_get_account_id)}"

    local registry_url=$(ecr_get_registry_url "$account_id" "$region")
    local password=$(ecr_get_login_password "$region")

    if [ -z "$password" ]; then
        print_error "Failed to get ECR login password"
        return 1
    fi

    echo "$password" | docker login --username AWS --password-stdin "$registry_url" 2>/dev/null
}

ecr_set_lifecycle_policy() {
    local repo_name="$1"
    local region="${2:-$(aws_get_region)}"
    local max_images="${3:-30}"

    local policy=$(cat <<EOF
{
    "rules": [
        {
            "rulePriority": 1,
            "description": "Keep only last $max_images images",
            "selection": {
                "tagStatus": "any",
                "countType": "imageCountMoreThan",
                "countNumber": $max_images
            },
            "action": {
                "type": "expire"
            }
        }
    ]
}
EOF
)

    aws ecr put-lifecycle-policy \
        --repository-name "$repo_name" \
        --lifecycle-policy-text "$policy" \
        --region "$region" \
        --output json 2>/dev/null
}

# =============================================================================
# Parameter Store Functions
# =============================================================================

ssm_param_exists() {
    local name="$1"
    local region="${2:-$(aws_get_region)}"

    aws ssm get-parameter --name "$name" --region "$region" &>/dev/null
}

ssm_get_param() {
    local name="$1"
    local region="${2:-$(aws_get_region)}"
    local with_decryption="${3:-true}"

    if [ "$with_decryption" = true ]; then
        aws ssm get-parameter --name "$name" --region "$region" --with-decryption --output json 2>/dev/null
    else
        aws ssm get-parameter --name "$name" --region "$region" --output json 2>/dev/null
    fi
}

ssm_get_param_value() {
    local name="$1"
    local region="${2:-$(aws_get_region)}"
    local with_decryption="${3:-true}"

    local result=$(ssm_get_param "$name" "$region" "$with_decryption")
    json_get "$result" '.Parameter.Value'
}

ssm_put_param() {
    local name="$1"
    local value="$2"
    local type="${3:-String}"
    local region="${4:-$(aws_get_region)}"
    local description="${5:-}"
    local overwrite="${6:-true}"

    local cmd="aws ssm put-parameter --name \"$name\" --value \"$value\" --type \"$type\" --region \"$region\""

    if [ -n "$description" ]; then
        cmd="$cmd --description \"$description\""
    fi

    if [ "$overwrite" = true ]; then
        cmd="$cmd --overwrite"
    fi

    eval "$cmd" --output json 2>/dev/null
}

ssm_delete_param() {
    local name="$1"
    local region="${2:-$(aws_get_region)}"

    aws ssm delete-parameter --name "$name" --region "$region" 2>/dev/null
}

ssm_list_params() {
    local path="${1:-/}"
    local region="${2:-$(aws_get_region)}"
    local recursive="${3:-true}"

    if [ "$recursive" = true ]; then
        aws ssm get-parameters-by-path \
            --path "$path" \
            --recursive \
            --region "$region" \
            --output json 2>/dev/null
    else
        aws ssm get-parameters-by-path \
            --path "$path" \
            --region "$region" \
            --output json 2>/dev/null
    fi
}

ssm_describe_params() {
    local filters="${1:-}"
    local region="${2:-$(aws_get_region)}"

    if [ -n "$filters" ]; then
        aws ssm describe-parameters \
            --parameter-filters "$filters" \
            --region "$region" \
            --output json 2>/dev/null
    else
        aws ssm describe-parameters \
            --region "$region" \
            --output json 2>/dev/null
    fi
}

# =============================================================================
# Lambda Functions
# =============================================================================

lambda_exists() {
    local function_name="$1"
    local region="${2:-$(aws_get_region)}"

    aws lambda get-function --function-name "$function_name" --region "$region" &>/dev/null
}

lambda_create() {
    local function_name="$1"
    local runtime="$2"
    local handler="$3"
    local role_arn="$4"
    local zip_file="$5"
    local region="${6:-$(aws_get_region)}"
    local memory="${7:-128}"
    local timeout="${8:-30}"

    print_info "Creating Lambda function: $function_name"

    aws lambda create-function \
        --function-name "$function_name" \
        --runtime "$runtime" \
        --handler "$handler" \
        --role "$role_arn" \
        --zip-file "fileb://$zip_file" \
        --memory-size "$memory" \
        --timeout "$timeout" \
        --region "$region" \
        --output json 2>/dev/null
}

lambda_update_code() {
    local function_name="$1"
    local zip_file="$2"
    local region="${3:-$(aws_get_region)}"

    print_info "Updating Lambda code: $function_name"

    aws lambda update-function-code \
        --function-name "$function_name" \
        --zip-file "fileb://$zip_file" \
        --region "$region" \
        --output json 2>/dev/null
}

lambda_invoke() {
    local function_name="$1"
    local payload="${2:-{}}"
    local region="${3:-$(aws_get_region)}"
    local output_file="${4:-/tmp/lambda-response.json}"

    aws lambda invoke \
        --function-name "$function_name" \
        --payload "$payload" \
        --region "$region" \
        --cli-binary-format raw-in-base64-out \
        "$output_file" \
        --output json 2>/dev/null
}

lambda_get_info() {
    local function_name="$1"
    local region="${2:-$(aws_get_region)}"

    aws lambda get-function \
        --function-name "$function_name" \
        --region "$region" \
        --output json 2>/dev/null
}

lambda_list() {
    local region="${1:-$(aws_get_region)}"

    aws lambda list-functions \
        --region "$region" \
        --query 'Functions[*].{Name:FunctionName,Runtime:Runtime,Memory:MemorySize,Timeout:Timeout,Modified:LastModified}' \
        --output json 2>/dev/null
}

lambda_get_logs() {
    local function_name="$1"
    local region="${2:-$(aws_get_region)}"
    local start_time="${3:-$(($(date +%s) - 3600))000}"
    local limit="${4:-50}"

    local log_group="/aws/lambda/$function_name"

    aws logs filter-log-events \
        --log-group-name "$log_group" \
        --start-time "$start_time" \
        --limit "$limit" \
        --region "$region" \
        --output json 2>/dev/null
}

lambda_delete() {
    local function_name="$1"
    local region="${2:-$(aws_get_region)}"

    print_info "Deleting Lambda function: $function_name"

    aws lambda delete-function \
        --function-name "$function_name" \
        --region "$region" 2>/dev/null
}

iam_create_lambda_role() {
    local role_name="$1"

    print_info "Creating IAM role for Lambda: $role_name"

    local trust_policy=$(cat <<EOF
{
    "Version": "2012-10-17",
    "Statement": [{
        "Effect": "Allow",
        "Principal": {"Service": "lambda.amazonaws.com"},
        "Action": "sts:AssumeRole"
    }]
}
EOF
)

    aws iam create-role \
        --role-name "$role_name" \
        --assume-role-policy-document "$trust_policy" \
        --output json 2>/dev/null

    # Attach basic execution role
    aws iam attach-role-policy \
        --role-name "$role_name" \
        --policy-arn "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole" 2>/dev/null

    print_info "Waiting for IAM role propagation (10s)..."
    sleep 10
}

# =============================================================================
# Secrets Manager Functions
# =============================================================================

secrets_exists() {
    local secret_name="$1"
    local region="${2:-$(aws_get_region)}"

    aws secretsmanager describe-secret --secret-id "$secret_name" --region "$region" &>/dev/null
}

secrets_create() {
    local secret_name="$1"
    local secret_value="$2"
    local region="${3:-$(aws_get_region)}"
    local description="${4:-}"

    print_info "Creating secret: $secret_name"

    local cmd="aws secretsmanager create-secret --name \"$secret_name\" --region \"$region\""

    # Check if it's JSON
    if echo "$secret_value" | jq . &>/dev/null; then
        cmd="$cmd --secret-string '$secret_value'"
    else
        cmd="$cmd --secret-string \"$secret_value\""
    fi

    if [ -n "$description" ]; then
        cmd="$cmd --description \"$description\""
    fi

    eval "$cmd" --output json 2>/dev/null
}

secrets_get() {
    local secret_name="$1"
    local region="${2:-$(aws_get_region)}"

    aws secretsmanager get-secret-value \
        --secret-id "$secret_name" \
        --region "$region" \
        --output json 2>/dev/null
}

secrets_get_value() {
    local secret_name="$1"
    local region="${2:-$(aws_get_region)}"

    local result=$(secrets_get "$secret_name" "$region")
    json_get "$result" '.SecretString'
}

secrets_update() {
    local secret_name="$1"
    local secret_value="$2"
    local region="${3:-$(aws_get_region)}"

    print_info "Updating secret: $secret_name"

    aws secretsmanager put-secret-value \
        --secret-id "$secret_name" \
        --secret-string "$secret_value" \
        --region "$region" \
        --output json 2>/dev/null
}

secrets_delete() {
    local secret_name="$1"
    local region="${2:-$(aws_get_region)}"
    local force="${3:-false}"

    print_info "Deleting secret: $secret_name"

    if [ "$force" = true ]; then
        aws secretsmanager delete-secret \
            --secret-id "$secret_name" \
            --force-delete-without-recovery \
            --region "$region" 2>/dev/null
    else
        aws secretsmanager delete-secret \
            --secret-id "$secret_name" \
            --region "$region" 2>/dev/null
    fi
}

secrets_list() {
    local region="${1:-$(aws_get_region)}"

    aws secretsmanager list-secrets \
        --region "$region" \
        --query 'SecretList[*].{Name:Name,Description:Description,Created:CreatedDate,Modified:LastChangedDate}' \
        --output json 2>/dev/null
}

secrets_describe() {
    local secret_name="$1"
    local region="${2:-$(aws_get_region)}"

    aws secretsmanager describe-secret \
        --secret-id "$secret_name" \
        --region "$region" \
        --output json 2>/dev/null
}

# =============================================================================
# SQS Functions
# =============================================================================

sqs_queue_exists() {
    local queue_name="$1"
    local region="${2:-$(aws_get_region)}"

    aws sqs get-queue-url --queue-name "$queue_name" --region "$region" &>/dev/null
}

sqs_get_queue_url() {
    local queue_name="$1"
    local region="${2:-$(aws_get_region)}"

    aws sqs get-queue-url --queue-name "$queue_name" --region "$region" --query 'QueueUrl' --output text 2>/dev/null
}

sqs_create_queue() {
    local queue_name="$1"
    local region="${2:-$(aws_get_region)}"
    local visibility_timeout="${3:-30}"
    local message_retention="${4:-345600}"

    print_info "Creating SQS queue: $queue_name"

    aws sqs create-queue \
        --queue-name "$queue_name" \
        --region "$region" \
        --attributes "VisibilityTimeout=$visibility_timeout,MessageRetentionPeriod=$message_retention" \
        --output json 2>/dev/null
}

sqs_create_fifo_queue() {
    local queue_name="$1"
    local region="${2:-$(aws_get_region)}"

    # FIFO queues must end with .fifo
    if [[ ! "$queue_name" =~ \.fifo$ ]]; then
        queue_name="${queue_name}.fifo"
    fi

    print_info "Creating FIFO queue: $queue_name"

    aws sqs create-queue \
        --queue-name "$queue_name" \
        --region "$region" \
        --attributes "FifoQueue=true,ContentBasedDeduplication=true" \
        --output json 2>/dev/null
}

sqs_delete_queue() {
    local queue_url="$1"
    local region="${2:-$(aws_get_region)}"

    print_info "Deleting SQS queue"
    aws sqs delete-queue --queue-url "$queue_url" --region "$region" 2>/dev/null
}

sqs_send_message() {
    local queue_url="$1"
    local message="$2"
    local region="${3:-$(aws_get_region)}"

    aws sqs send-message \
        --queue-url "$queue_url" \
        --message-body "$message" \
        --region "$region" \
        --output json 2>/dev/null
}

sqs_receive_message() {
    local queue_url="$1"
    local region="${2:-$(aws_get_region)}"
    local max_messages="${3:-1}"
    local wait_time="${4:-0}"

    aws sqs receive-message \
        --queue-url "$queue_url" \
        --max-number-of-messages "$max_messages" \
        --wait-time-seconds "$wait_time" \
        --region "$region" \
        --output json 2>/dev/null
}

sqs_get_attributes() {
    local queue_url="$1"
    local region="${2:-$(aws_get_region)}"

    aws sqs get-queue-attributes \
        --queue-url "$queue_url" \
        --attribute-names All \
        --region "$region" \
        --output json 2>/dev/null
}

sqs_list_queues() {
    local region="${1:-$(aws_get_region)}"
    local prefix="${2:-}"

    if [ -n "$prefix" ]; then
        aws sqs list-queues --region "$region" --queue-name-prefix "$prefix" --output json 2>/dev/null
    else
        aws sqs list-queues --region "$region" --output json 2>/dev/null
    fi
}

sqs_purge_queue() {
    local queue_url="$1"
    local region="${2:-$(aws_get_region)}"

    print_info "Purging SQS queue"
    aws sqs purge-queue --queue-url "$queue_url" --region "$region" 2>/dev/null
}

# =============================================================================
# SNS Functions
# =============================================================================

sns_topic_exists() {
    local topic_name="$1"
    local region="${2:-$(aws_get_region)}"

    local topics=$(aws sns list-topics --region "$region" --query "Topics[?contains(TopicArn, ':$topic_name')].TopicArn" --output text 2>/dev/null)
    [ -n "$topics" ]
}

sns_get_topic_arn() {
    local topic_name="$1"
    local region="${2:-$(aws_get_region)}"
    local account_id="${3:-$(aws_get_account_id)}"

    echo "arn:aws:sns:${region}:${account_id}:${topic_name}"
}

sns_create_topic() {
    local topic_name="$1"
    local region="${2:-$(aws_get_region)}"

    print_info "Creating SNS topic: $topic_name"

    aws sns create-topic \
        --name "$topic_name" \
        --region "$region" \
        --output json 2>/dev/null
}

sns_delete_topic() {
    local topic_arn="$1"
    local region="${2:-$(aws_get_region)}"

    print_info "Deleting SNS topic"
    aws sns delete-topic --topic-arn "$topic_arn" --region "$region" 2>/dev/null
}

sns_publish() {
    local topic_arn="$1"
    local message="$2"
    local region="${3:-$(aws_get_region)}"
    local subject="${4:-}"

    local cmd="aws sns publish --topic-arn \"$topic_arn\" --message \"$message\" --region \"$region\""

    if [ -n "$subject" ]; then
        cmd="$cmd --subject \"$subject\""
    fi

    eval "$cmd" --output json 2>/dev/null
}

sns_subscribe() {
    local topic_arn="$1"
    local protocol="$2"
    local endpoint="$3"
    local region="${4:-$(aws_get_region)}"

    print_info "Subscribing to SNS topic"

    aws sns subscribe \
        --topic-arn "$topic_arn" \
        --protocol "$protocol" \
        --notification-endpoint "$endpoint" \
        --region "$region" \
        --output json 2>/dev/null
}

sns_list_topics() {
    local region="${1:-$(aws_get_region)}"

    aws sns list-topics --region "$region" --output json 2>/dev/null
}

sns_list_subscriptions() {
    local topic_arn="$1"
    local region="${2:-$(aws_get_region)}"

    if [ -n "$topic_arn" ]; then
        aws sns list-subscriptions-by-topic --topic-arn "$topic_arn" --region "$region" --output json 2>/dev/null
    else
        aws sns list-subscriptions --region "$region" --output json 2>/dev/null
    fi
}

sns_get_topic_attributes() {
    local topic_arn="$1"
    local region="${2:-$(aws_get_region)}"

    aws sns get-topic-attributes --topic-arn "$topic_arn" --region "$region" --output json 2>/dev/null
}

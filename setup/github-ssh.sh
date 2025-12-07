#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# WSL Ubuntu - GitHub SSH Key Setup
# =============================================================================

# Configuration
EMAIL="kuromailserver@gmail.com"
NAME="Toshifumi Kurosawa"
KEY_FILE="$HOME/.ssh/id_ed25519"
SSH_CONFIG="$HOME/.ssh/config"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log_step() { echo -e "\n${GREEN}[$1]${NC} $2"; }
log_info() { echo -e "${CYAN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

echo "========================================="
echo "   GitHub SSH Key Setup"
echo "   Email: ${EMAIL}"
echo "========================================="

# -----------------------------------------------------------------------------
# 1. Create ~/.ssh directory
# -----------------------------------------------------------------------------
log_step "1/5" "Preparing ~/.ssh directory..."
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# -----------------------------------------------------------------------------
# 2. Generate SSH key (no passphrase)
# -----------------------------------------------------------------------------
log_step "2/5" "Generating SSH key..."

if [[ -f "$KEY_FILE" ]]; then
    log_warn "SSH key already exists: $KEY_FILE"
    read -p "Overwrite? (y/N): " confirm
    if [[ "$confirm" != "y" ]]; then
        log_info "Skipping key generation"
    else
        ssh-keygen -t ed25519 -C "$EMAIL" -f "$KEY_FILE" -N ""
        log_info "Key generated: $KEY_FILE"
    fi
else
    ssh-keygen -t ed25519 -C "$EMAIL" -f "$KEY_FILE" -N ""
    log_info "Key generated: $KEY_FILE"
fi

chmod 600 "$KEY_FILE"
chmod 644 "${KEY_FILE}.pub"

# -----------------------------------------------------------------------------
# 3. Start SSH agent and add key
# -----------------------------------------------------------------------------
log_step "3/5" "Starting SSH agent..."
eval "$(ssh-agent -s)"
ssh-add "$KEY_FILE"

# -----------------------------------------------------------------------------
# 4. Configure ~/.ssh/config
# -----------------------------------------------------------------------------
log_step "4/5" "Configuring SSH config..."

GITHUB_CONFIG="Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519
    AddKeysToAgent yes"

if [[ -f "$SSH_CONFIG" ]] && grep -q "Host github.com" "$SSH_CONFIG"; then
    log_warn "GitHub config already exists in $SSH_CONFIG"
else
    echo "" >> "$SSH_CONFIG"
    echo "$GITHUB_CONFIG" >> "$SSH_CONFIG"
    chmod 600 "$SSH_CONFIG"
    log_info "GitHub config added to $SSH_CONFIG"
fi

# -----------------------------------------------------------------------------
# 5. Configure Git global settings
# -----------------------------------------------------------------------------
log_step "5/6" "Configuring Git global settings..."

CURRENT_NAME=$(git config --global user.name 2>/dev/null || echo "")
CURRENT_EMAIL=$(git config --global user.email 2>/dev/null || echo "")

if [[ "$CURRENT_NAME" == "$NAME" && "$CURRENT_EMAIL" == "$EMAIL" ]]; then
    log_info "Git config already set correctly"
else
    git config --global user.name "$NAME"
    git config --global user.email "$EMAIL"
    log_info "Git config set: $NAME <$EMAIL>"
fi

# -----------------------------------------------------------------------------
# 6. Display public key
# -----------------------------------------------------------------------------
log_step "6/6" "Setup complete!"

echo ""
echo "========================================="
echo "  Public Key (copy this to GitHub)"
echo "========================================="
echo ""
cat "${KEY_FILE}.pub"
echo ""
echo "========================================="
echo ""
echo "Next steps:"
echo "  1. Go to: https://github.com/settings/ssh/new"
echo "  2. Title: WSL Ubuntu (or any name)"
echo "  3. Key: Paste the public key above"
echo "  4. Click 'Add SSH key'"
echo ""
echo "After adding to GitHub, test connection:"
echo "  ssh -T git@github.com"
echo ""
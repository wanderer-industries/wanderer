#!/bin/bash
# Install Git hooks for the Wanderer project
# Usage: ./.github/hooks/install-hooks.sh

set -e

echo "🔧 Installing Git hooks for Wanderer..."

# Get the repository root
REPO_ROOT=$(git rev-parse --show-toplevel)
HOOKS_DIR="$REPO_ROOT/.github/hooks"
GIT_HOOKS_DIR="$REPO_ROOT/.git/hooks"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Check if we're in a git repository
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "❌ Not in a git repository"
    exit 1
fi

# Create git hooks directory if it doesn't exist
if [ ! -d "$GIT_HOOKS_DIR" ]; then
    mkdir -p "$GIT_HOOKS_DIR"
fi

# Install pre-commit hook
if [ -f "$HOOKS_DIR/pre-commit" ]; then
    print_status $YELLOW "📋 Installing pre-commit hook..."
    
    # Make the hook executable
    chmod +x "$HOOKS_DIR/pre-commit"
    
    # Create symlink to git hooks directory
    if [ -L "$GIT_HOOKS_DIR/pre-commit" ] || [ -f "$GIT_HOOKS_DIR/pre-commit" ]; then
        rm "$GIT_HOOKS_DIR/pre-commit"
    fi
    
    ln -sf "../../.github/hooks/pre-commit" "$GIT_HOOKS_DIR/pre-commit"
    print_status $GREEN "✅ Pre-commit hook installed"
else
    echo "❌ Pre-commit hook not found at $HOOKS_DIR/pre-commit"
    exit 1
fi

# Install prepare-commit-msg hook if it exists
if [ -f "$HOOKS_DIR/prepare-commit-msg" ]; then
    print_status $YELLOW "📝 Installing prepare-commit-msg hook..."
    
    chmod +x "$HOOKS_DIR/prepare-commit-msg"
    
    if [ -L "$GIT_HOOKS_DIR/prepare-commit-msg" ] || [ -f "$GIT_HOOKS_DIR/prepare-commit-msg" ]; then
        rm "$GIT_HOOKS_DIR/prepare-commit-msg"
    fi
    
    ln -sf "../../.github/hooks/prepare-commit-msg" "$GIT_HOOKS_DIR/prepare-commit-msg"
    print_status $GREEN "✅ Prepare-commit-msg hook installed"
fi

# Install commit-msg hook if it exists
if [ -f "$HOOKS_DIR/commit-msg" ]; then
    print_status $YELLOW "💬 Installing commit-msg hook..."
    
    chmod +x "$HOOKS_DIR/commit-msg"
    
    if [ -L "$GIT_HOOKS_DIR/commit-msg" ] || [ -f "$GIT_HOOKS_DIR/commit-msg" ]; then
        rm "$GIT_HOOKS_DIR/commit-msg"
    fi
    
    ln -sf "../../.github/hooks/commit-msg" "$GIT_HOOKS_DIR/commit-msg"
    print_status $GREEN "✅ Commit-msg hook installed"
fi

echo ""
echo "🎉 Git hooks installation complete!"
echo ""
echo "Installed hooks:"
ls -la "$GIT_HOOKS_DIR" | grep -E "(pre-commit|prepare-commit-msg|commit-msg)" || echo "  None"
echo ""
echo "These hooks will run automatically on:"
echo "  - pre-commit: Before each commit (quality checks)"
echo "  - prepare-commit-msg: When preparing commit messages"
echo "  - commit-msg: When validating commit messages"
echo ""
echo "To bypass hooks (not recommended): git commit --no-verify"
echo ""
print_status $GREEN "✅ Ready to commit with quality checks enabled!"
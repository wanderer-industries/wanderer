# 🧪 Simple CI Setup

A straightforward continuous integration setup for the Wanderer project that focuses on essential quality checks.

## 🚀 Quick Start

### 1. Install Git Hooks (Optional)
```bash
# Install pre-commit hooks for local quality checks
./.github/hooks/install-hooks.sh
```

### 2. Run Tests Locally
```bash
# Run the test suite
mix test

# Check code formatting
mix format --check-formatted

# Run static analysis
mix credo --strict

# Check compilation warnings
mix compile --warnings-as-errors
```

## 📋 CI Pipeline

The CI pipeline runs on every pull request and push to main/develop branches with these steps:

1. **Setup Environment** - Elixir 1.16, OTP 26, PostgreSQL 15
2. **Install Dependencies** - Cache and install Elixir deps
3. **Code Quality Checks**:
   - Code formatting (`mix format --check-formatted`)
   - Compilation warnings (`mix compile --warnings-as-errors`)
   - Static analysis (`mix credo --strict`) - non-blocking
4. **Database Setup** - Create and migrate test database
5. **Test Execution** - Run the full test suite

## 🔧 Local Development

### Pre-commit Hook
The optional pre-commit hook runs basic quality checks:
- Merge conflict marker detection
- Code formatting validation
- Compilation check

### Manual Quality Checks
```bash
# Format code
mix format

# Fix compilation warnings
mix compile

# Address Credo issues
mix credo --strict

# Run tests
mix test
```

## 📁 Archived Complex Workflows

Complex CI workflows have been moved to `.github/workflows/archive/` for future reference:
- `qa-validation.yml` - Comprehensive QA pipeline
- `ci-monitoring.yml` - Performance monitoring
- `test-maintenance.yml` - Automated test optimization
- `flaky-test-detection.yml` - Test stability monitoring
- `enhanced-testing.yml` - Advanced testing strategies

These can be restored if more sophisticated CI capabilities are needed in the future.

## 🎯 Philosophy

This setup prioritizes:
- **Simplicity** - Easy to understand and maintain
- **Speed** - Fast feedback on essential checks
- **Reliability** - Focused on critical quality gates
- **Developer Experience** - Minimal friction for development workflow

For projects requiring more sophisticated quality assurance, the archived workflows provide a comprehensive foundation.
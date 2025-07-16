# 🔍 QA Validation Pipeline

A comprehensive quality assurance system for the Wanderer project that enforces quality gates at every level of development.

## 🚀 Quick Start

### 1. Install Git Hooks
```bash
# Install pre-commit hooks for local quality checks
./.github/hooks/install-hooks.sh
```

### 2. Run Quality Report
```bash
# Generate comprehensive quality report
mix quality_report

# Generate markdown report
mix quality_report --format markdown --output quality_report.md

# CI mode with exit codes
mix quality_report --ci --format json
```

### 3. Check Progressive Quality
```bash
# Check progressive improvement targets
mix quality.progressive_check

# Enforce quality targets (fails if not met)
mix quality.progressive_check --enforce-targets

# Update quality baselines
mix quality.update_baselines
```

## 📋 Components

### 1. GitHub Actions Workflow (`.github/workflows/qa-validation.yml`)

**Comprehensive CI/CD pipeline with multiple quality gates:**

- **Pre-validation**: Fast early checks
  - Commit message validation (conventional format)
  - Merge conflict detection
  - Large file detection
  - Basic file validation

- **Backend Quality Gates**: 
  - Compilation (with warnings as errors)
  - Code formatting (mix format)
  - Code quality analysis (Credo)
  - Static type analysis (Dialyzer)
  - Security scanning (deps.audit, Sobelow)

- **Test Execution**:
  - Full test suite with coverage
  - Performance monitoring
  - Flaky test detection
  - Coverage threshold enforcement (80%)

- **Frontend Quality Gates**:
  - ESLint code quality
  - Prettier formatting
  - TypeScript type checking
  - Frontend tests
  - Production build verification

- **API Contract Validation**:
  - OpenAPI spec generation
  - Contract test execution
  - Breaking change detection
  - API compatibility checks

- **Security & Compliance**:
  - Dependency vulnerability scanning
  - Secret detection (TruffleHog)
  - Hardcoded credential detection
  - Security policy enforcement

### 2. Pre-commit Hooks (`.github/hooks/pre-commit`)

**Local quality checks before commit:**

- Commit message format validation
- File size and content checks
- Merge conflict detection
- Secret/credential scanning
- Elixir quality checks (compilation, formatting, Credo)
- Frontend quality checks (ESLint, Prettier, TypeScript)
- Quick test validation for modified files

### 3. Quality Reporting System

**Advanced quality metrics and reporting:**

#### `mix quality_report`
- **Comprehensive metrics**: Compilation, code quality, testing, coverage, security
- **Multiple formats**: JSON, Markdown, Text
- **Baseline comparison**: Track quality improvements over time
- **CI integration**: Machine-readable output with exit codes
- **Component scoring**: Individual scores for each quality aspect

#### `mix quality.progressive_check`
- **Progressive improvement**: Enforce gradual quality improvements
- **Configurable targets**: Different thresholds for different environments
- **Baseline tracking**: Compare against historical quality metrics
- **Enforcement mode**: Fail builds if quality decreases

#### `mix quality.update_baselines`
- **Baseline management**: Update quality baselines after improvements
- **Historical tracking**: Maintain timestamped baseline archives
- **Quality gates**: Prevent baseline updates when quality decreases

## 🎯 Quality Gates

### Overall Score Calculation
- **Compilation**: 100 - (warnings × 5)
- **Code Quality**: 100 - credo_issues  
- **Testing**: test_success_rate
- **Coverage**: coverage_percentage
- **Security**: 100 (clean) / 50 (issues) / 75 (unavailable)

### Progressive Targets
- **Overall Score**: 70% minimum, 85% target, 95% excellent
- **Compilation Warnings**: 0 target, ≤5 acceptable
- **Credo Issues**: ≤5 target, ≤50 acceptable  
- **Test Coverage**: 70% minimum, 90% target, 95% excellent
- **Test Failures**: 0 (no tolerance)

## 🔧 Configuration

### Environment Variables
```bash
# Enable performance monitoring in tests
PERFORMANCE_MONITORING=true

# Database configuration for CI
DB_HOST=localhost
MIX_TEST_PARTITION=
```

### Quality Thresholds
Thresholds are defined in the progressive check system and can be customized:

```elixir
# Standard mode
compilation_warnings: ≤5
credo_issues: ≤50
test_coverage: ≥70%

# Strict mode (--strict flag)
compilation_warnings: 0
credo_issues: ≤10
test_coverage: ≥85%
```

## 📊 Reports and Metrics

### Quality Report Output
```
📊 QUALITY REPORT
═══════════════════════════════════════════════════════════

Overall Score: 87.4% ✅ Good

Component Breakdown:
────────────────────────────────────────────────────────────
📝 Compilation:   100%  (0 warnings)
🎯 Code Quality:  85%   (15 Credo issues)
🧪 Testing:       100%  (179 tests)
📊 Coverage:      82%
🛡️  Security:     100%  (clean)
```

### Baseline Comparison
```
Baseline Comparison:
────────────────────────────────────────────────────────────
Score Change:    +3.2%
Test Change:     +12 tests
Coverage Change: +5.1%
```

## 🚦 Integration Points

### GitHub Actions Integration
- **Pull Request Comments**: Automatic quality summaries
- **Status Checks**: Required checks for merge protection
- **Artifact Storage**: Quality reports and coverage data
- **Progressive Enforcement**: Gradual quality improvement

### Local Development
- **Pre-commit Hooks**: Catch issues before commit
- **IDE Integration**: Works with standard Elixir/Phoenix tooling
- **Developer Feedback**: Immediate quality feedback

### CI/CD Pipeline
- **Quality Gates**: Block deployments on quality failures
- **Trend Analysis**: Track quality metrics over time
- **Automated Reporting**: Slack/email notifications for quality issues

## 🛠️ Usage Examples

### Daily Development
```bash
# Before starting work
mix quality_report

# Before committing (automatic via hooks)
git commit -m "feat: add new feature"

# Check progressive improvement
mix quality.progressive_check
```

### Release Process
```bash
# Ensure quality meets release standards
mix quality.progressive_check --enforce-targets --strict

# Update baselines for next iteration
mix quality.update_baselines

# Generate release quality report
mix quality_report --format markdown --output RELEASE_QUALITY.md
```

### CI/CD Integration
```yaml
# In your GitHub Actions workflow
- name: Quality Check
  run: mix quality_report --ci --format json

- name: Progressive Quality
  run: mix quality.progressive_check --enforce-targets
```

## 🎉 Benefits

### For Developers
- **Immediate Feedback**: Catch issues before they reach CI
- **Quality Awareness**: Understand project quality trends
- **Consistent Standards**: Automated enforcement of quality standards

### For Teams
- **Quality Trends**: Track improvement over time
- **Automated Enforcement**: Reduce manual code review burden
- **Comprehensive Coverage**: All aspects of quality monitored

### For Projects
- **Quality Assurance**: Maintain high code quality
- **Technical Debt**: Prevent accumulation of quality issues
- **Reliability**: Improved test coverage and stability

## 🔍 Monitoring and Maintenance

### Quality Metrics Tracking
- Overall quality score trends
- Component-level quality tracking
- Progressive improvement validation
- Baseline drift detection

### Automated Maintenance
- Quality baseline updates
- Threshold adjustments based on team capabilities
- Performance regression detection
- Security vulnerability monitoring

This QA validation pipeline ensures comprehensive quality enforcement at every stage of development, from local commits to production deployments.
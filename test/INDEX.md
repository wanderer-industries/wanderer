# Testing Documentation Index

This index provides navigation to all testing-related documentation in the Wanderer project.

## 🚀 Getting Started

**New to testing in Wanderer?** Start here:

1. **[TESTING_GUIDE.md](TESTING_GUIDE.md)** - Complete testing guide (Start here!)
   - Quick 10-minute setup
   - Test standards and patterns
   - Examples for all test types
   - Troubleshooting reference

2. **[DEVELOPER_ONBOARDING.md](DEVELOPER_ONBOARDING.md)** - Team onboarding guide
   - Testing culture and practices
   - Learning progression
   - Team collaboration

## 📚 Core Documentation

### Essential Guides

| Document | Purpose | Audience | When to Use |
|----------|---------|----------|------------|
| **[TESTING_GUIDE.md](TESTING_GUIDE.md)** | Complete testing reference | All developers | Primary reference for testing |
| **[WORKFLOW.md](WORKFLOW.md)** | Visual workflows and decision trees | All developers | When you need visual guidance |
| **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** | Problem-solving guide | All developers | When tests fail or behave unexpectedly |

### Specialized Guides

| Document | Purpose | Audience | When to Use |
|----------|---------|----------|------------|
| **[ARCHITECTURE.md](ARCHITECTURE.md)** | Testing architecture overview | Tech leads, architects | Understanding system design |
| **[CONTRACT_TESTING_PLAN.md](CONTRACT_TESTING_PLAN.md)** | API contract testing | API developers | API integration testing |
| **[QA_PIPELINE.md](QA_PIPELINE.md)** | CI/CD and quality pipeline | DevOps, QA engineers | CI/CD troubleshooting |

## 📖 Learning Paths

### For New Developers

1. **Day 1**: Read [TESTING_GUIDE.md](TESTING_GUIDE.md) Quick Start section
2. **Week 1**: Complete [DEVELOPER_ONBOARDING.md](DEVELOPER_ONBOARDING.md)
3. **Month 1**: Master all examples in [TESTING_GUIDE.md](TESTING_GUIDE.md)
4. **Month 2**: Study [ARCHITECTURE.md](ARCHITECTURE.md) for system understanding

### For Experienced Developers

1. **Review**: [TESTING_GUIDE.md](TESTING_GUIDE.md) standards section
2. **Implement**: Advanced patterns from [TESTING_GUIDE.md](TESTING_GUIDE.md)
3. **Contribute**: Improve [ARCHITECTURE.md](ARCHITECTURE.md) and processes

### For Team Leads

1. **Understand**: [ARCHITECTURE.md](ARCHITECTURE.md) for system design
2. **Setup**: [QA_PIPELINE.md](QA_PIPELINE.md) for CI/CD
3. **Mentor**: Using [DEVELOPER_ONBOARDING.md](DEVELOPER_ONBOARDING.md)

## 🛠️ Quick Reference

### Common Tasks

| Task | Document | Section |
|------|----------|---------|
| Run first test | [TESTING_GUIDE.md](TESTING_GUIDE.md) | Quick Start |
| Write unit test | [TESTING_GUIDE.md](TESTING_GUIDE.md) | Test Types & Examples |
| Fix failing test | [TROUBLESHOOTING.md](TROUBLESHOOTING.md) | Common Issues |
| API contract test | [CONTRACT_TESTING_PLAN.md](CONTRACT_TESTING_PLAN.md) | Implementation |
| Performance test | [TESTING_GUIDE.md](TESTING_GUIDE.md) | Performance Guidelines |
| Mock external service | [TESTING_GUIDE.md](TESTING_GUIDE.md) | Mock and Stub Patterns |

### Test Commands

```bash
# Run all tests
mix test

# Run with coverage
mix test --cover

# Run specific test file
mix test test/path/to/test.exs

# Run failed tests only
mix test --failed

# Run with detailed output
mix test --trace
```

## 🎯 Test Categories

### By Type

| Category | Description | Example Location |
|----------|-------------|------------------|
| **Unit Tests** | Fast, isolated function tests | `test/unit/` |
| **Integration Tests** | Database and service integration | `test/integration/` |
| **Contract Tests** | API specification validation | `test/contract/` |
| **Performance Tests** | Load and memory testing | `test/performance/` |

### By Module

| Module | Test Location | Coverage |
|--------|---------------|----------|
| **API Resources** | `test/unit/wanderer_app/api/` | 90%+ |
| **Web Controllers** | `test/integration/controllers/` | 85%+ |
| **Business Logic** | `test/unit/wanderer_app/` | 95%+ |
| **External Services** | `test/unit/wanderer_app/external/` | 80%+ |

## 📊 Coverage and Metrics

### Current Status

- **Overall Coverage**: 85%+ (target)
- **Unit Test Coverage**: 90%+ (target)
- **Integration Test Coverage**: 80%+ (target)
- **Critical Path Coverage**: 95%+ (target)

### Monitoring

- **CI Dashboard**: GitHub Actions workflows
- **Coverage Reports**: Generated on each PR
- **Performance Metrics**: Tracked in CI
- **Quality Gates**: Automated enforcement

## 🔧 Tools and Setup

### Required Tools

| Tool | Purpose | Installation |
|------|---------|-------------|
| **ExUnit** | Core testing framework | Built into Elixir |
| **Mox** | Mocking library | `{:mox, "~> 1.0", only: :test}` |
| **Wallaby** | Browser testing | `{:wallaby, "~> 0.30.0", only: :test}` |
| **ExCoveralls** | Coverage reporting | `{:excoveralls, "~> 0.15", only: :test}` |

### Environment Setup

```bash
# Install dependencies
mix deps.get

# Setup test database
MIX_ENV=test mix ecto.setup

# Run all tests
mix test

# Generate coverage report
mix coveralls.html
```

## 🏗️ Architecture Overview

### Test Structure

```
test/
├── unit/                    # Fast, isolated tests
├── integration/             # Database + service tests
├── contract/                # API contract validation
├── performance/             # Load and memory tests
├── support/                 # Test helpers and utilities
├── fixtures/                # Test data
└── factory.ex               # Data factories
```

### Key Components

- **Test Cases**: `DataCase`, `ConnCase`, `ChannelCase`
- **Factories**: Data generation with ExMachina
- **Mocks**: External service mocking with Mox
- **Helpers**: Common test utilities
- **Fixtures**: Static test data

## 🤝 Contributing

### Adding New Tests

1. **Choose appropriate test type** (unit, integration, contract)
2. **Follow naming conventions** from [TESTING_GUIDE.md](TESTING_GUIDE.md)
3. **Use proper test case** (`DataCase`, `ConnCase`, etc.)
4. **Add to appropriate directory** (`test/unit/`, `test/integration/`, etc.)
5. **Update documentation** if adding new patterns

### Improving Documentation

1. **Update this index** when adding new documents
2. **Follow existing structure** and formatting
3. **Include working examples** in all guides
4. **Cross-reference** related sections
5. **Validate examples** work with current codebase

### Code Review Checklist

- [ ] Tests follow AAA pattern
- [ ] Appropriate test case used
- [ ] Proper assertions and error handling
- [ ] Mock usage follows guidelines
- [ ] Performance considerations addressed
- [ ] Documentation updated if needed

## 📞 Getting Help

### Quick Help

1. **Check [TROUBLESHOOTING.md](TROUBLESHOOTING.md)** for common issues
2. **Review [TESTING_GUIDE.md](TESTING_GUIDE.md)** for patterns
3. **Ask in team chat** for quick questions
4. **Create issue** for documentation improvements

### Escalation Path

1. **Team Lead**: For architectural decisions
2. **DevOps**: For CI/CD pipeline issues
3. **QA Team**: For testing strategy questions
4. **Product**: For acceptance criteria clarity

---

## 📝 Document Status

| Document | Status | Last Updated | Next Review |
|----------|---------|-------------|-------------|
| [TESTING_GUIDE.md](TESTING_GUIDE.md) | ✅ Current | 2025-01-15 | 2025-02-15 |
| [WORKFLOW.md](WORKFLOW.md) | ✅ Current | 2025-01-15 | 2025-02-15 |
| [TROUBLESHOOTING.md](TROUBLESHOOTING.md) | ✅ Current | 2025-01-15 | 2025-02-15 |
| [ARCHITECTURE.md](ARCHITECTURE.md) | ✅ Current | 2025-01-15 | 2025-02-15 |
| [DEVELOPER_ONBOARDING.md](DEVELOPER_ONBOARDING.md) | ✅ Current | 2025-01-15 | 2025-02-15 |
| [CONTRACT_TESTING_PLAN.md](CONTRACT_TESTING_PLAN.md) | ✅ Current | 2025-01-15 | 2025-02-15 |

---

*This index is maintained by the development team. For updates or improvements, please submit a pull request or create an issue.*
# 🔄 Testing Workflow Guide

This guide provides visual workflows and step-by-step processes for effective testing in WandererApp.

## 📊 Testing Workflow Overview

```mermaid
graph TD
    A[📝 Write Code] --> B{🤔 What to Test?}
    
    B -->|Function/Module| C[🔬 Unit Test]
    B -->|API Endpoint| D[🔗 Integration Test] 
    B -->|OpenAPI Schema| E[📋 Contract Test]
    B -->|Performance Critical| F[⚡ Performance Test]
    
    C --> G[🏃 Run Tests]
    D --> G
    E --> G
    F --> G
    
    G --> H{✅ Tests Pass?}
    
    H -->|❌ No| I[🐛 Debug & Fix]
    H -->|✅ Yes| J[📊 Check Coverage]
    
    I --> G
    J --> K{📈 Coverage OK?}
    
    K -->|❌ No| L[➕ Add More Tests]
    K -->|✅ Yes| M[🚀 Ready to Commit]
    
    L --> G
    M --> N[🎯 Performance Check]
    N --> O[📋 Code Review]
    
    style A fill:#e1f5fe
    style M fill:#e8f5e8
    style I fill:#ffebee
```

## 🎯 Test-Driven Development (TDD) Flow

```mermaid
sequenceDiagram
    participant Dev as 👨‍💻 Developer
    participant Test as 🧪 Test Suite
    participant Code as 💻 Code
    participant CI as 🔄 CI/CD
    
    Dev->>Test: 1. Write failing test
    Note over Test: ❌ Red - Test fails
    
    Dev->>Code: 2. Write minimal code
    Dev->>Test: 3. Run test
    Note over Test: ✅ Green - Test passes
    
    Dev->>Code: 4. Refactor code
    Dev->>Test: 5. Ensure tests still pass
    Note over Test: 🔄 Refactor - Maintain green
    
    Dev->>CI: 6. Push to repository
    CI->>Test: 7. Run full test suite
    CI->>Dev: 8. Report results
```

## 🏗️ Testing Strategy by Component

### 1. **API Development Workflow**

```mermaid
flowchart LR
    A[🎯 Design API] --> B[📝 Write OpenAPI Spec]
    B --> C[🧪 Create Contract Tests]
    C --> D[🔗 Write Integration Tests]
    D --> E[💻 Implement Controller]
    E --> F[🏃 Run Tests]
    F --> G{✅ All Pass?}
    G -->|❌| H[🐛 Fix Issues]
    G -->|✅| I[⚡ Add Performance Tests]
    H --> F
    I --> J[🚀 Ready for Review]
    
    style A fill:#e3f2fd
    style J fill:#e8f5e8
```

### 2. **Business Logic Development**

```mermaid
flowchart TD
    A[🎯 Define Requirements] --> B[🧪 Write Unit Tests]
    B --> C[💻 Implement Logic]
    C --> D[🏃 Run Unit Tests]
    D --> E{✅ Pass?}
    E -->|❌| F[🐛 Fix Logic]
    E -->|✅| G[🔗 Integration Tests]
    F --> D
    G --> H[🏃 Run Integration Tests]
    H --> I{✅ Pass?}
    I -->|❌| J[🐛 Fix Integration]
    I -->|✅| K[📊 Check Coverage]
    J --> H
    K --> L[🚀 Complete]
    
    style A fill:#f3e5f5
    style L fill:#e8f5e8
```

## 🧪 Test Creation Decision Tree

```mermaid
graph TD
    A[🤔 Need to Test?] --> B{What am I testing?}
    
    B -->|Pure Function| C[🔬 Unit Test]
    B -->|Database Operation| D[🗄️ Unit Test + DB]
    B -->|HTTP Endpoint| E[🔗 Integration Test]
    B -->|External API| F[🎭 Mock + Integration]
    B -->|Performance Critical| G[⚡ Performance Test]
    B -->|User Interface| H[🖥️ Feature Test]
    
    C --> I[test/unit/]
    D --> I
    E --> J[test/integration/]
    F --> J
    G --> K[test/performance/]
    H --> L[test/e2e/]
    
    I --> M[🏃 Run: mix test test/unit/]
    J --> N[🏃 Run: mix test test/integration/]
    K --> O[🏃 Run: mix test.performance]
    L --> P[🏃 Run: mix test test/e2e/]
    
    style C fill:#e8f5e8
    style E fill:#e3f2fd
    style G fill:#fff3e0
    style H fill:#fce4ec
```

## 🔄 Continuous Testing Workflow

### Daily Development Cycle

```mermaid
gantt
    title Daily Testing Workflow
    dateFormat HH:mm
    axisFormat %H:%M
    
    section Morning
    Pull latest code      :done, pull, 09:00, 09:15
    Run full test suite   :done, test1, 09:15, 09:30
    Review test results   :done, review1, 09:30, 09:45
    
    section Development
    Write tests           :active, write1, 09:45, 11:00
    Implement feature     :active, impl1, 11:00, 12:30
    Run targeted tests    :test2, 12:30, 12:45
    
    section Integration
    Run integration tests :test3, 14:00, 14:30
    Performance check     :perf1, 14:30, 15:00
    Fix issues           :fix1, 15:00, 16:00
    
    section Completion
    Final test run       :test4, 16:00, 16:15
    Code review prep     :review2, 16:15, 16:30
```

### Pre-Commit Checklist Workflow

```mermaid
flowchart TD
    A[📝 Ready to Commit] --> B[🧪 Run Unit Tests]
    B --> C{✅ Pass?}
    C -->|❌| D[🐛 Fix Unit Tests]
    C -->|✅| E[🔗 Run Integration Tests]
    D --> B
    E --> F{✅ Pass?}
    F -->|❌| G[🐛 Fix Integration]
    F -->|✅| H[⚡ Performance Check]
    G --> E
    H --> I{📊 Within Budget?}
    I -->|❌| J[🔧 Optimize Performance]
    I -->|✅| K[📋 Check Coverage]
    J --> H
    K --> L{📈 Coverage > 80%?}
    L -->|❌| M[➕ Add Missing Tests]
    L -->|✅| N[🎯 Run Contract Tests]
    M --> B
    N --> O{✅ Schema Valid?}
    O -->|❌| P[🔧 Fix Schema Issues]
    O -->|✅| Q[🚀 Ready to Push]
    P --> N
    
    style A fill:#e1f5fe
    style Q fill:#e8f5e8
    style D fill:#ffebee
    style G fill:#ffebee
    style J fill:#fff3e0
    style M fill:#fff3e0
    style P fill:#ffebee
```

## 🏃‍♂️ Quick Testing Commands Reference

### Development Commands
```bash
# Quick test run during development
mix test --stale                    # Only run stale tests
mix test test/unit/my_test.exs:42   # Specific test line
mix test --failed                   # Only failed tests
```

### Performance Monitoring
```bash
# Enable performance monitoring
export PERFORMANCE_MONITORING=true

# Run with dashboard
mix test.performance --dashboard

# Performance budget check
mix test.performance --budget 1000
```

### Coverage and Quality
```bash
# Test coverage
mix test --cover

# Quality report
mix quality_report

# Test optimization
mix test_optimize
```

## 🎭 Testing Patterns by Scenario

### 1. **New Feature Development**

```mermaid
sequenceDiagram
    participant PM as 📋 Product Manager
    participant Dev as 👨‍💻 Developer
    participant Tests as 🧪 Tests
    participant Code as 💻 Code
    
    PM->>Dev: 📝 Feature requirements
    Dev->>Tests: 🧪 Write failing tests
    Dev->>Code: 💻 Implement feature
    Dev->>Tests: 🏃 Run tests
    
    alt Tests fail
        Tests->>Dev: ❌ Failure details
        Dev->>Code: 🔧 Fix implementation
        Dev->>Tests: 🏃 Re-run tests
    else Tests pass
        Tests->>Dev: ✅ All green
        Dev->>PM: 🚀 Feature ready
    end
```

### 2. **Bug Fix Workflow**

```mermaid
flowchart TD
    A[🐛 Bug Report] --> B[🔍 Reproduce Bug]
    B --> C[🧪 Write Failing Test]
    C --> D[💻 Fix Code]
    D --> E[🏃 Run Test]
    E --> F{✅ Test Passes?}
    F -->|❌| G[🔧 Adjust Fix]
    F -->|✅| H[🏃 Run Full Suite]
    G --> E
    H --> I{✅ All Pass?}
    I -->|❌| J[🐛 Fix Regressions]
    I -->|✅| K[🚀 Deploy Fix]
    J --> H
    
    style A fill:#ffebee
    style K fill:#e8f5e8
```

### 3. **Refactoring Workflow**

```mermaid
graph LR
    A[🔧 Start Refactoring] --> B[🧪 Ensure Tests Pass]
    B --> C[💻 Refactor Code]
    C --> D[🏃 Run Tests]
    D --> E{✅ Still Pass?}
    E -->|❌| F[🐛 Fix Breaking Changes]
    E -->|✅| G[⚡ Performance Check]
    F --> D
    G --> H{📊 Performance OK?}
    H -->|❌| I[🔧 Optimize]
    H -->|✅| J[🚀 Complete]
    I --> G
    
    style A fill:#e3f2fd
    style J fill:#e8f5e8
```

## 📊 Test Health Monitoring

### Test Suite Health Dashboard

```mermaid
graph TD
    A[📊 Test Health] --> B[⏱️ Execution Time]
    A --> C[📈 Coverage Metrics]
    A --> D[🔄 Flaky Test Detection]
    A --> E[⚡ Performance Budgets]
    
    B --> B1[🎯 Target: < 5 minutes]
    B --> B2[📊 Current: 3.2 minutes]
    B --> B3[📈 Trend: Stable]
    
    C --> C1[🎯 Target: > 80%]
    C --> C2[📊 Current: 87%]
    C --> C3[📈 Trend: Improving]
    
    D --> D1[🎯 Target: < 5%]
    D --> D2[📊 Current: 2%]
    D --> D3[📈 Trend: Decreasing]
    
    E --> E1[🎯 Target: 95% within budget]
    E --> E2[📊 Current: 98%]
    E --> E3[📈 Trend: Stable]
    
    style B1 fill:#e8f5e8
    style C1 fill:#e8f5e8
    style D1 fill:#e8f5e8
    style E1 fill:#e8f5e8
```

## 🚨 Troubleshooting Workflows

### When Tests Fail

```mermaid
flowchart TD
    A[❌ Test Failure] --> B{🤔 Type of Failure?}
    
    B -->|Unit Test| C[🔬 Check Logic]
    B -->|Integration| D[🔗 Check API/DB]
    B -->|Performance| E[⚡ Check Performance]
    B -->|Flaky Test| F[🎭 Check Race Conditions]
    
    C --> G[🧪 Debug with IEx]
    D --> H[🔍 Check Logs]
    E --> I[📊 Profile Code]
    F --> J[🎲 Run Multiple Times]
    
    G --> K[🔧 Fix Logic]
    H --> L[🔧 Fix API/DB]
    I --> M[🔧 Optimize Performance]
    J --> N[🔧 Fix Race Condition]
    
    K --> O[🏃 Re-run Tests]
    L --> O
    M --> O
    N --> O
    
    O --> P{✅ Fixed?}
    P -->|❌| Q[🔄 Repeat Process]
    P -->|✅| R[🚀 Success]
    
    Q --> B
    
    style A fill:#ffebee
    style R fill:#e8f5e8
```

### Performance Issue Resolution

```mermaid
sequenceDiagram
    participant Dev as 👨‍💻 Developer
    participant Monitor as 📊 Performance Monitor
    participant Profiler as 🔍 Profiler
    participant Dashboard as 📱 Dashboard
    
    Dev->>Monitor: 🏃 Run performance tests
    Monitor->>Dev: ⚠️ Budget exceeded
    
    Dev->>Dashboard: 📊 Check real-time metrics
    Dashboard->>Dev: 📈 Memory usage spike
    
    Dev->>Profiler: 🔍 Profile problematic code
    Profiler->>Dev: 🎯 Bottleneck identified
    
    Dev->>Dev: 🔧 Optimize code
    
    Dev->>Monitor: 🏃 Re-run tests
    Monitor->>Dev: ✅ Within budget
```

## 📚 Testing Best Practices Workflow

### Code Review Checklist

```mermaid
graph TD
    A[📋 Code Review] --> B{🧪 Tests Included?}
    B -->|❌| C[❌ Request Tests]
    B -->|✅| D{📊 Coverage Adequate?}
    D -->|❌| E[❌ Request More Tests]
    D -->|✅| F{⚡ Performance OK?}
    F -->|❌| G[❌ Request Optimization]
    F -->|✅| H{🎯 Tests Well-Written?}
    H -->|❌| I[❌ Request Improvements]
    H -->|✅| J[✅ Approve]
    
    C --> K[🔄 Return to Developer]
    E --> K
    G --> K
    I --> K
    
    style J fill:#e8f5e8
    style C fill:#ffebee
    style E fill:#ffebee
    style G fill:#ffebee
    style I fill:#ffebee
```

## 🎯 Success Metrics

Track these key metrics for testing health:

| Metric | Target | Current | Status |
|--------|--------|---------|---------|
| Test Execution Time | < 5 minutes | 3.2 minutes | ✅ |
| Code Coverage | > 80% | 87% | ✅ |
| Flaky Test Rate | < 5% | 2% | ✅ |
| Performance Budget Compliance | > 95% | 98% | ✅ |
| Test-to-Code Ratio | 2:1 | 2.3:1 | ✅ |
| Bug Escape Rate | < 10% | 6% | ✅ |

---

This workflow guide provides visual representations and step-by-step processes to help developers understand and follow effective testing practices in WandererApp.
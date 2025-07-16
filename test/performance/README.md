# Enhanced Performance Testing & Monitoring

This directory contains the enhanced performance testing and monitoring infrastructure for the Wanderer application. The system provides comprehensive performance analysis, real-time monitoring, and regression detection capabilities.

## 🚀 Quick Start

### Running Tests with Performance Monitoring

```bash
# Run all tests with basic performance monitoring
PERFORMANCE_MONITORING=true mix test

# Run tests with real-time dashboard
mix test.performance --dashboard

# Run only performance tests
mix test.performance test/performance/

# Run with custom performance budget
mix test.performance --budget 1000 --dashboard
```

### Accessing the Performance Dashboard

When running with `--dashboard`, a real-time performance dashboard will be available at:
- **URL**: `http://localhost:4001`
- **Features**: Live metrics, charts, alerts, system health

## 📊 Components

### 1. Enhanced Performance Monitor (`enhanced_performance_monitor.ex`)

The core monitoring engine that provides:

- **Real-time Metrics**: Live performance data collection
- **Resource Profiling**: CPU, memory, I/O monitoring  
- **Performance Budgets**: Configurable thresholds per test type
- **Trend Analysis**: Historical performance tracking
- **Regression Detection**: Automated performance regression alerts

**Usage:**
```elixir
# Start monitoring a test
monitor_ref = WandererApp.EnhancedPerformanceMonitor.start_test_monitoring("MyTest", :api_test)

# Your test code here...

# Stop monitoring and get results
{:ok, metrics} = WandererApp.EnhancedPerformanceMonitor.stop_test_monitoring(monitor_ref)
```

### 2. Performance Dashboard (`performance_dashboard.ex`)

A real-time web interface showing:

- **System Metrics**: Memory, CPU, process count
- **Active Tests**: Currently running tests and their performance
- **Performance Alerts**: Budget violations and regressions
- **Trend Charts**: Memory usage over time

**Features:**
- WebSocket-based real-time updates
- Interactive charts using Chart.js
- Performance alert notifications
- Mobile-responsive design

### 3. Performance Test Framework (`performance_test_framework.ex`)

Advanced testing utilities including:

- **Performance Tests**: Tests with specific performance budgets
- **Benchmark Tests**: Integration with Benchee for detailed benchmarking
- **Load Testing**: Multi-user concurrent testing
- **Memory Leak Detection**: Automated memory leak testing
- **Stress Testing**: Progressive load testing to find breaking points
- **Database Performance**: Query performance and N+1 detection

**Example Usage:**
```elixir
defmodule MyPerformanceTest do
  use WandererApp.PerformanceTestFramework, test_type: :api_test

  performance_test "API should respond quickly", budget: 500 do
    # Test that must complete within 500ms
  end

  benchmark_test "Database query benchmark", max_avg_time: 100 do
    # Benchmarked operation
  end
end
```

### 4. Mix Task (`mix test.performance`)

Comprehensive CLI tool for performance testing:

```bash
# Available commands
mix test.performance --help

# Key options
--dashboard         # Start real-time dashboard  
--benchmarks-only   # Run only benchmark tests
--stress-test       # Include stress testing
--budget MS         # Set performance budget
--save-results      # Save results for trend analysis
```

## 📈 Performance Test Types

### Unit Tests
- **Budget**: 100ms (default)
- **Focus**: Individual function performance
- **Monitoring**: Memory, CPU, duration

### Integration Tests  
- **Budget**: 2000ms (default)
- **Focus**: Component interaction performance
- **Monitoring**: Database queries, cache operations, network calls

### API Tests
- **Budget**: 5000ms (default) 
- **Focus**: HTTP endpoint performance
- **Monitoring**: Response times, throughput, resource usage

### End-to-End Tests
- **Budget**: 10000ms (default)
- **Focus**: Full user journey performance
- **Monitoring**: Browser interactions, page load times

## 🔍 Performance Monitoring Features

### Real-time Metrics Collection
- Test execution timing
- Memory usage patterns
- CPU utilization
- Database query counts
- Cache hit/miss ratios
- Network request tracking

### Trend Analysis
- Historical performance data
- Performance regression detection
- Statistical trend analysis with slope calculation
- 95th and 99th percentile tracking

### Performance Budgets
```elixir
# Set custom budgets
WandererApp.EnhancedPerformanceMonitor.set_performance_budget(:unit_test, 50)
WandererApp.EnhancedPerformanceMonitor.set_performance_budget(:api_test, 1000)
```

### Load Testing
```elixir
endpoint_config = %{
  method: :get,
  path: "/api/maps/123/systems",
  headers: [{"authorization", "Bearer token"}],
  body: nil
}

load_config = %{
  concurrent_users: 20,
  duration_seconds: 60,
  ramp_up_seconds: 10
}

results = WandererApp.PerformanceTestFramework.load_test_endpoint(endpoint_config, load_config)
```

### Memory Leak Detection
```elixir
test_function = fn ->
  # Operations that might leak memory
end

results = WandererApp.PerformanceTestFramework.memory_leak_test(test_function, 100)
assert not results.leak_detected
```

## 📋 Example Performance Tests

### API Performance Test
```elixir
performance_test "Map API endpoint performance", budget: 800 do
  conn = get(build_conn(), "/api/maps/#{map.slug}")
  assert json_response(conn, 200)
end
```

### Database Performance Test
```elixir
test "Database query performance" do
  query_function = fn -> WandererApp.MapRepo.get(map.id) end
  
  results = database_performance_test(query_function, %{
    iterations: 50,
    max_avg_time: 50,
    check_n_plus_one: true
  })
  
  assert results.performance_ok
  assert not results.n_plus_one_detected
end
```

### Stress Test
```elixir
@tag :stress_test
test "API stress test" do
  test_function = fn ->
    get(build_conn(), "/api/maps/#{map.slug}")
  end

  results = stress_test(test_function, %{
    initial_load: 1,
    max_load: 50,
    step_size: 5,
    step_duration: 10
  })
  
  assert results.performance_summary.can_handle_load >= 20
end
```

## 📊 Performance Reports

### Automatic Report Generation
The system automatically generates comprehensive performance reports including:

- **Test Execution Summary**: Duration, success rate, performance budget compliance
- **Performance Trends**: Historical performance analysis  
- **Regression Detection**: Tests that have significantly slowed down
- **System Health**: Memory, CPU, process metrics
- **Recommendations**: Actionable performance optimization suggestions

### Report Storage
```bash
# Reports are saved to:
test/performance_results/
├── performance_2024-01-15T10-30-00.json  # Detailed reports
├── trends.json                            # Historical trend data
└── latest_report.json                     # Most recent summary
```

## 🚨 Performance Alerts

The system provides real-time alerts for:

- **Budget Violations**: Tests exceeding performance budgets
- **Performance Regressions**: Tests becoming significantly slower
- **Memory Leaks**: Detected memory usage growth
- **System Health Issues**: High memory/CPU usage
- **Flaky Test Detection**: Tests with inconsistent performance

## 🔧 Configuration

### Environment Variables
```bash
# Enable performance monitoring
export PERFORMANCE_MONITORING=true

# Enable verbose test output
export VERBOSE_TESTS=true

# Dashboard port (default: 4001)
export PERFORMANCE_DASHBOARD_PORT=4001
```

### Performance Budgets
```elixir
# In test configuration
config :wanderer_app, :performance_budgets,
  unit_test: 100,
  integration_test: 2000,
  api_test: 5000,
  e2e_test: 10000
```

## 🤝 Integration with Existing Infrastructure

The enhanced performance monitoring integrates seamlessly with:

- **Existing Test Monitor**: Extends flaky test detection
- **Test Performance Monitor**: Builds on existing timing infrastructure  
- **Integration Monitoring**: Enhances system metrics collection
- **Telemetry**: Integrates with Phoenix telemetry and PromEx
- **CI/CD**: GitHub Actions workflows for automated performance testing

## 📚 Best Practices

### Writing Performance Tests
1. **Set Realistic Budgets**: Based on actual user expectations
2. **Test Real Scenarios**: Use realistic data sizes and patterns
3. **Monitor Resources**: Track memory, CPU, and I/O usage
4. **Run Consistently**: Use the same environment for trend analysis
5. **Act on Regressions**: Address performance issues immediately

### Performance Optimization
1. **Profile Before Optimizing**: Use the monitoring data to identify bottlenecks
2. **Optimize Hot Paths**: Focus on frequently used code paths
3. **Monitor Trends**: Watch for gradual performance degradation
4. **Load Test Regularly**: Verify performance under realistic load
5. **Document Performance Requirements**: Maintain clear performance standards

## 🔮 Future Enhancements

Planned improvements include:

- **Distributed Load Testing**: Multi-node load testing capabilities
- **Performance Comparisons**: A/B testing for performance optimizations
- **AI-Powered Analysis**: Machine learning for performance anomaly detection  
- **Integration with APM**: Application Performance Monitoring integration
- **Custom Metrics**: User-defined performance metrics and alerting

## 🆘 Troubleshooting

### Common Issues

**Dashboard not starting:**
```bash
# Check if port is available
lsof -i :4001

# Try different port  
mix test.performance --dashboard --port 4002
```

**High memory usage during tests:**
```bash
# Enable memory profiling
PERFORMANCE_MONITORING=true mix test.performance --save-results
```

**Performance test failures:**
```bash
# Check performance budget settings
mix test.performance --budget 2000

# Review performance trends
cat test/performance_results/trends.json
```

### Getting Help

- Review the performance dashboard for real-time insights
- Check the generated performance reports in `test/performance_results/`
- Enable verbose logging with `VERBOSE_TESTS=true`
- Run `mix test.performance --help` for CLI options

---

The enhanced performance monitoring system provides comprehensive insights into test performance, helping maintain high application performance standards and quickly identify regressions.
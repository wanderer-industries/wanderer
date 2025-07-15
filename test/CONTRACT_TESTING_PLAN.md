# Contract Testing Comprehensive Plan

## Current State Analysis

### Existing Contract Tests
- **Error Response Contract Tests**: `test/contract/error_response_contract_test.exs` - Tests standard error response schemas across API endpoints
- **OpenAPI Contract Helpers**: `test/support/openapi_contract_helpers.ex` - Provides utilities for OpenAPI schema validation
- **OpenAPI Spec Analyzer**: `test/support/openapi_spec_analyzer.ex` - Analyzes API specifications and generates reports

### Current Coverage
- ✅ Error response schema validation (401, 404, 400, 422, 429, 406, 405, 500)
- ✅ OpenAPI schema validation helpers
- ✅ Basic contract validation framework
- ❌ Individual endpoint contract tests
- ❌ Request schema validation
- ❌ Response schema validation for success scenarios
- ❌ External service contract tests (ESI API)
- ❌ Consumer-driven contract tests

## Comprehensive Contract Testing Strategy

### 1. API Contract Testing Expansion

#### 1.1 Complete Endpoint Coverage
Create contract tests for all API endpoints:

**Core API Endpoints** (Priority: High)
- Maps API (`/api/maps/*`)
- Characters API (`/api/characters/*`)
- Map Systems API (`/api/maps/{id}/systems/*`)
- Map Connections API (`/api/maps/{id}/connections/*`)
- Map Signatures API (`/api/maps/{id}/signatures/*`)
- Access Lists API (`/api/acls/*`)

**Supporting API Endpoints** (Priority: Medium)
- Map Webhooks API (`/api/maps/{id}/webhooks/*`)
- Map Audit API (`/api/maps/{id}/audit/*`)
- Common API (`/api/common/*`)
- Events API (`/api/events/*`)

#### 1.2 Request/Response Contract Tests
For each endpoint, implement:
- **Request Schema Validation**: Validate request bodies, parameters, headers
- **Response Schema Validation**: Validate success responses (200, 201, 204)
- **Error Response Validation**: Comprehensive error scenario testing
- **Content Type Validation**: Ensure proper content negotiation

#### 1.3 Business Logic Contract Tests
- **Authentication/Authorization**: API key validation, role-based access
- **Data Relationships**: Foreign key constraints, cascading operations
- **Business Rules**: Map ownership, character tracking, access control

### 2. External Service Contract Testing

#### 2.1 EVE ESI API Contract Tests
**Current Integration**: `lib/wanderer_app/esi/api_client.ex`

**Test Coverage Needed**:
- Server status endpoint contract
- Character information endpoints
- Solar system data endpoints
- Route calculation endpoints
- Authentication/token validation

**Implementation Strategy**:
```elixir
# Create ESI contract tests
test/contract/esi_contract_test.exs
test/support/esi_contract_helpers.ex
```

#### 2.2 Third-Party Service Contracts
- **zkillboard API**: Kill data integration
- **External webhook endpoints**: Outbound webhook contracts
- **License service**: License validation contracts

### 3. Consumer-Driven Contract Testing

#### 3.1 Frontend Contract Tests
**Current Frontend**: React SPA with real-time updates

**Contract Areas**:
- WebSocket message contracts
- REST API response contracts
- Real-time event contracts
- Error handling contracts

#### 3.2 External Consumer Contracts
- **Webhook consumers**: External systems consuming map events
- **API clients**: Third-party applications using the API
- **Mobile apps**: If applicable

### 4. Schema Evolution and Backward Compatibility

#### 4.1 API Versioning Contract Tests
- **v1 API stability**: Ensure v1 endpoints remain stable
- **Schema evolution**: Test backward compatibility
- **Deprecation handling**: Validate deprecated endpoint behavior

#### 4.2 Database Schema Contract Tests
- **Migration contracts**: Ensure schema changes don't break API contracts
- **Data integrity**: Validate data consistency across schema changes

## Implementation Plan

### Phase 1: Foundation (Weeks 1-2)
1. **Enhanced Contract Test Framework**
   - Extend `openapi_contract_helpers.ex`
   - Add request validation helpers
   - Create parameterized contract test generators

2. **Core API Contract Tests**
   - Maps API contract tests
   - Characters API contract tests
   - Authentication/authorization contract tests

### Phase 2: Comprehensive API Coverage (Weeks 3-4)
1. **Complete Endpoint Coverage**
   - All remaining API endpoints
   - Request/response validation
   - Error scenario testing

2. **External Service Contracts**
   - ESI API contract tests
   - Third-party service contracts
   - Mock service contract validation

### Phase 3: Advanced Contract Testing (Weeks 5-6)
1. **Consumer-Driven Contracts**
   - Frontend contract tests
   - External consumer contracts
   - Real-time event contracts

2. **Schema Evolution Testing**
   - Backward compatibility tests
   - Migration contract tests
   - Version compatibility validation

### Phase 4: Automation and Monitoring (Weeks 7-8)
1. **CI/CD Integration**
   - Automated contract validation
   - Contract regression detection
   - Performance impact monitoring

2. **Contract Documentation**
   - Contract test documentation
   - API contract specifications
   - Consumer contract guides

## Test File Structure

```
test/
├── contract/
│   ├── api/
│   │   ├── maps_contract_test.exs
│   │   ├── characters_contract_test.exs
│   │   ├── map_systems_contract_test.exs
│   │   ├── map_connections_contract_test.exs
│   │   ├── access_lists_contract_test.exs
│   │   └── webhooks_contract_test.exs
│   ├── external/
│   │   ├── esi_contract_test.exs
│   │   ├── zkillboard_contract_test.exs
│   │   └── license_service_contract_test.exs
│   ├── consumer/
│   │   ├── frontend_contract_test.exs
│   │   ├── websocket_contract_test.exs
│   │   └── webhook_consumer_contract_test.exs
│   ├── schema/
│   │   ├── evolution_contract_test.exs
│   │   ├── migration_contract_test.exs
│   │   └── version_compatibility_test.exs
│   └── error_response_contract_test.exs (existing)
├── support/
│   ├── contract_helpers/
│   │   ├── api_contract_helpers.ex
│   │   ├── external_contract_helpers.ex
│   │   ├── consumer_contract_helpers.ex
│   │   └── schema_contract_helpers.ex
│   ├── openapi_contract_helpers.ex (existing)
│   └── openapi_spec_analyzer.ex (existing)
```

## Testing Tools and Libraries

### Current Tools
- **OpenApiSpex**: OpenAPI specification and validation
- **ExUnit**: Base testing framework
- **Mox**: Mocking library for external services

### Additional Tools Needed
- **Bypass**: HTTP request/response mocking for external services
- **Pact**: Consumer-driven contract testing (if needed)
- **ExVCR**: HTTP interaction recording for contract tests

## Quality Metrics

### Contract Test Coverage Metrics
- **Endpoint Coverage**: % of API endpoints with contract tests
- **Schema Coverage**: % of request/response schemas validated
- **Error Scenario Coverage**: % of error conditions tested
- **External Service Coverage**: % of external dependencies tested

### Success Criteria
- 100% API endpoint contract coverage
- 95% request/response schema validation
- 90% error scenario coverage
- 80% external service contract coverage
- Contract test execution time < 30 seconds
- Zero contract regression failures in production

## Maintenance and Evolution

### Contract Test Maintenance
- **Automated contract generation**: Generate tests from OpenAPI specs
- **Contract drift detection**: Monitor for API changes without test updates
- **Performance monitoring**: Track contract test execution time
- **Documentation updates**: Keep contract documentation current

### Evolution Strategy
- **Schema versioning**: Handle API version changes
- **Backward compatibility**: Ensure older consumers continue to work
- **Breaking change detection**: Identify potentially breaking changes
- **Migration support**: Provide migration paths for API changes

## Implementation Priority

### High Priority (Immediate)
1. Maps API contract tests
2. Characters API contract tests
3. ESI API contract tests
4. Request/response schema validation

### Medium Priority (Next Quarter)
1. Webhooks contract tests
2. Consumer-driven contract tests
3. Schema evolution tests
4. Performance contract tests

### Low Priority (Future)
1. Advanced monitoring and reporting
2. Automated contract generation
3. Integration with external contract testing tools
4. Cross-service contract validation

## Getting Started

### Quick Start Commands
```bash
# Run existing contract tests
mix test test/contract/

# Run all contract tests (after implementation)
mix test test/contract/ --include contract

# Generate contract test report
mix test.contract.report

# Validate API specification
mix openapi.validate

# Generate contract tests from OpenAPI spec
mix contract.generate
```

### Development Workflow
1. **API Change**: When adding/modifying API endpoints
2. **Contract First**: Update OpenAPI specification
3. **Generate Tests**: Auto-generate contract test skeletons
4. **Implement Tests**: Add specific contract validations
5. **Validate**: Run contract tests before deployment
6. **Monitor**: Track contract compliance in production

This comprehensive plan will significantly improve the reliability and maintainability of the API by ensuring all contracts are properly tested and validated.
# Implementation Plans

## 0. Test Suite Improvement Plan (PRIORITY)

### **Current State Analysis**
- Test suite quality rating: **8.5/10** (enterprise-grade)
- **13 API controllers** total
- **5 well-tested** (both integration + unit): map_api, map_system_api, map_connection_api, character_api, common_api
- **5 integration-only**: access_list_api, access_list_member_api, map_audit_api, map_system_signature_api, map_system_structure_api  
- **3 untested**: ~~license_api~~ (disabled), map_events_api, map_webhooks_api

### **Quality Assurance Protocol - MANDATORY**
**After completing each task, MUST:**
1. Run full test suite: `make test`
2. Ensure all tests pass (zero failures)
3. Run linting/formatting: `make format`
4. Only proceed to next task after clean test run
5. Commit progress with meaningful message after each successful completion

**If any tests fail:** STOP → Fix → Retest → Continue

### **Implementation Plan**

#### **Phase 1: Critical Coverage Gaps** (Week 1-4)

**1.1A: ~~License API Controller Tests~~ - SKIPPED**
- Routes disabled in router.ex:299-312
- Skip until routes re-enabled

**1.1B: Map Events API Controller Tests** (Week 1)
- Create `test/integration/api/map_events_api_controller_test.exs`
- Create `test/unit/controllers/map_events_api_controller_test.exs`
- Test MapEventRelay interaction, since/limit params, error handling
- **QA:** `make test` → All pass → `make format` → Commit

**1.1C: Map Webhooks API Controller Tests** (Week 1)
- Create `test/integration/api/map_webhooks_api_controller_test.exs` 
- Create `test/unit/controllers/map_webhooks_api_controller_test.exs`
- Test webhook CRUD, secret rotation, toggle functionality
- **QA:** `make test` → All pass → `make format` → Commit

**1.2A: Access List Controllers Unit Tests** (Week 2)
- Create `test/unit/controllers/access_list_api_controller_test.exs`
- Create `test/unit/controllers/access_list_member_api_controller_test.exs`
- **QA:** `make test` → All pass → `make format` → Commit

**1.2B: Map Audit Controller Unit Tests** (Week 3)
- Create `test/unit/controllers/map_audit_api_controller_test.exs`
- **QA:** `make test` → All pass → `make format` → Commit

**1.2C: Map System Controllers Unit Tests** (Week 4)
- Create `test/unit/controllers/map_system_signature_api_controller_test.exs`
- Create `test/unit/controllers/map_system_structure_api_controller_test.exs`
- **QA:** `make test` → All pass → `make format` → Commit

#### **Phase 2: Performance Optimization** (Week 5-8)
- Async test optimization (30% faster execution)
- Test data management improvements
- Manual test automation
- **QA after each:** `make test` → Performance check → Commit

#### **Phase 3: Infrastructure** (Week 9-10)
- Enhanced performance monitoring
- Test documentation & standards
- **QA:** Test validation → Commit

#### **Phase 4: Advanced Features** (Week 11-12)
- Contract testing enhancement
- End-to-End testing
- **QA:** Full validation → Final commit

**Total Effort: 12 weeks**

---

## 1. Rally Point Notifications via Webhook/SSE

### **Current State Analysis**
- Rally points exist as "pings" with `type: 1` (rally_point)
- Internal PubSub events exist (`:ping_added`, `:ping_cancelled`) 
- **Gap**: Rally point events are NOT exposed to external events system
- Robust webhook/SSE infrastructure already exists and is production-ready

### **Implementation Plan**

#### **Phase 1: Extend External Event Types** (2-3 hours)
1. **Update Event Definitions** (`lib/wanderer_app/external_events/event.ex:42`)
   - Add `:rally_point_added` and `:rally_point_removed` to supported event types
   - Add event serialization for rally point data structure

2. **Add Event Mapping** (`lib/wanderer_app/map/server/map_server_pings_impl.ex:15-30`)
   - Map internal `:ping_added` → `:rally_point_added` when `type == 1`
   - Map internal `:ping_cancelled` → `:rally_point_removed` when `type == 1`

#### **Phase 2: Integrate with External Events System** (3-4 hours)
1. **Broadcast Rally Point Events** 
   - Modify `add_ping/2` and `cancel_ping/2` functions
   - Call `WandererApp.ExternalEvents.broadcast_event/2` for rally point types
   - Include relevant data: `map_id`, `system_id`, `character_id`, `message`, `timestamp`

2. **Event Payload Structure**
   ```elixir
   %{
     event_type: :rally_point_added,
     map_id: map_id,
     data: %{
       rally_point_id: ping.id,
       system_id: ping.system_id,
       character_id: ping.character_id,
       character_name: character.name,
       system_name: system.name,
       message: ping.message,
       created_at: ping.inserted_at
     }
   }
   ```

#### **Phase 3: Testing & Validation** (2-3 hours)
1. **Unit Tests**
   - Test event broadcasting in ping operations
   - Verify correct event type filtering
   - Test payload structure

2. **Integration Tests**
   - Test SSE delivery of rally point events
   - Test webhook delivery with proper signatures
   - Test event filtering and backfill functionality

**Total Effort: 7-10 hours**

---

## 2. Map Duplication API

### **Current State Analysis**
- No existing map duplication functionality
- Complex relationships: Maps → Systems → Connections → Signatures + ACLs
- Existing patterns for map creation and relationship management available

### **Implementation Plan**

#### **Phase 1: API Design & Validation** (4-5 hours)
1. **Design API Endpoint**
   ```
   POST /api/maps/{map_id}/duplicate
   {
     "name": "New Map Name",
     "slug": "new-map-slug", 
     "description": "Duplicated from original map",
     "copy_acls": true,
     "copy_characters": false,
     "copy_structures": true
   }
   ```

2. **Add Ash Action** (`lib/wanderer_app/api/map.ex`)
   - New `:duplicate` action with required/optional attributes
   - Validation for name uniqueness, slug format
   - Access control (only map owner/admin can duplicate)

#### **Phase 2: Core Duplication Logic** (8-10 hours)
1. **Map Duplication Service** (`lib/wanderer_app/map/operations/duplication.ex`)
   ```elixir
   defmodule WandererApp.Map.Operations.Duplication do
     def duplicate_map(source_map_id, attrs, opts \\ []) do
       # Multi-transaction approach
       Ash.Transaction.transaction([WandererApp.Api], fn ->
         with {:ok, source_map} <- load_source_map(source_map_id),
              {:ok, new_map} <- create_base_map(source_map, attrs),
              {:ok, _} <- copy_systems(source_map, new_map),
              {:ok, _} <- copy_connections(source_map, new_map),
              {:ok, _} <- copy_signatures(source_map, new_map, opts),
              {:ok, _} <- copy_acls(source_map, new_map, opts),
              {:ok, _} <- copy_characters(source_map, new_map, opts) do
           {:ok, new_map}
         end
       end)
     end
   end
   ```

2. **Individual Copy Operations**
   - `copy_systems/2` - Copy all map systems with position data
   - `copy_connections/2` - Recreate system connections 
   - `copy_signatures/3` - Copy signatures if enabled
   - `copy_acls/3` - Copy ACL relationships if enabled
   - `copy_characters/3` - Copy character settings if enabled

#### **Phase 3: Controller Implementation** (3-4 hours)
1. **API Controller** (`lib/wanderer_app_web/controllers/map_api_controller.ex`)
   - Add `duplicate` action
   - Parameter validation and sanitization
   - Authentication and authorization checks
   - Error handling and response formatting

2. **OpenAPI Schema** 
   - Request/response schema definitions
   - Example payloads and error responses

#### **Phase 4: Data Integrity & Relationships** (6-8 hours)
1. **System ID Mapping**
   - Create mapping table for old system_id → new system_id
   - Update all connection references during copy
   - Handle signature system references

2. **ACL Duplication Strategy**
   ```elixir
   # Option 1: Copy ACL references (shared ACLs)
   copy_acl_references(source_map, new_map)
   
   # Option 2: Clone ACLs entirely (independent ACLs)  
   clone_acls(source_map, new_map)
   ```

3. **Character Settings**
   - Copy character-map relationship settings
   - Preserve permissions and preferences
   - Handle character access validation

#### **Phase 5: Testing & Edge Cases** (5-6 hours)
1. **Comprehensive Test Suite**
   - Test all copy options (ACLs, characters, structures)
   - Test partial failures and rollback scenarios
   - Test large map duplication performance
   - Test authorization edge cases

2. **Integration Tests**
   - End-to-end API testing
   - Database constraint validation
   - Transaction rollback testing

**Total Effort: 26-33 hours**

---

## **Recommended Implementation Order**

### **Week 1: Rally Point Notifications** 
- **Effort**: 7-10 hours
- **Risk**: Low (extending existing system)
- **Value**: Immediate user benefit

### **Week 2-3: Map Duplication API**
- **Effort**: 26-33 hours  
- **Risk**: Medium (complex data relationships)
- **Value**: High user value, complex feature

### **Dependencies & Considerations**

**Rally Point Notifications:**
- No external dependencies
- Builds on solid existing infrastructure
- Low risk of breaking changes

**Map Duplication:**
- Consider map size limits for performance
- Database transaction timeout considerations
- May need background job processing for large maps
- Audit trail for duplication events

Both features leverage the existing robust architecture and should integrate smoothly with current systems.
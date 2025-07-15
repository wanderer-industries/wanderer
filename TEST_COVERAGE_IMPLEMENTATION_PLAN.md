# Test Coverage Implementation Plan
## From 17.6% to 25%+ Coverage

### Executive Summary

This plan outlines a strategic approach to increase test coverage from the current **17.6%** to **25%+** through targeted testing of high-impact areas. The plan focuses on quick wins and core business logic to maximize coverage gains while ensuring quality and maintainability.

### Current State Analysis

**Current Coverage: 17.6%**
- **Well-tested areas**: API controllers, web layer, contract testing
- **Major gaps**: Core business logic, utility modules, Ash API resources
- **Test infrastructure**: Excellent foundation with ExUnit, Mox, factories

---

## Phase 1: Quick Wins (Week 1-2)
**Target: 17.6% → 22% (+4.4% increase)**

### 1.1 Utility Modules Testing
**Estimated Coverage Gain: 2-3%**
**Implementation Effort: Low (2-3 days)**

#### Priority Files:
- `lib/wanderer_app/utils/eve_util.ex` - EVE Online utilities
- `lib/wanderer_app/utils/http_util.ex` - HTTP helper functions
- `lib/wanderer_app/utils/json_util.ex` - JSON file operations
- `lib/wanderer_app/utils/csv_util.ex` - CSV parsing utilities
- `lib/wanderer_app/cache.ex` - Cache operations

#### Implementation Example:
```elixir
# test/unit/utils/eve_util_test.exs
defmodule WandererApp.Utils.EVEUtilTest do
  use ExUnit.Case, async: true
  alias WandererApp.Utils.EVEUtil

  describe "get_portrait_url/2" do
    test "returns correct URL for valid eve_id" do
      assert EVEUtil.get_portrait_url(12345) == 
        "https://images.evetech.net/characters/12345/portrait?size=64"
    end
    
    test "handles nil eve_id with default" do
      assert EVEUtil.get_portrait_url(nil) == 
        "https://images.evetech.net/characters/0/portrait?size=64"
    end
    
    test "handles different sizes" do
      assert EVEUtil.get_portrait_url(12345, 128) == 
        "https://images.evetech.net/characters/12345/portrait?size=128"
    end
  end

  describe "get_corporation_logo_url/2" do
    test "returns correct corporation logo URL" do
      assert EVEUtil.get_corporation_logo_url(98765) == 
        "https://images.evetech.net/corporations/98765/logo?size=64"
    end
  end

  describe "format_isk/1" do
    test "formats ISK amounts correctly" do
      assert EVEUtil.format_isk(1000000) == "1.0M"
      assert EVEUtil.format_isk(1500000) == "1.5M"
      assert EVEUtil.format_isk(1000) == "1.0K"
      assert EVEUtil.format_isk(500) == "500"
    end
  end
end
```

### 1.2 Repository Layer Testing
**Estimated Coverage Gain: 1-2%**
**Implementation Effort: Low (2-3 days)**

#### Priority Files:
- `lib/wanderer_app/repositories/access_list_repo.ex`
- `lib/wanderer_app/repositories/map_repo.ex`
- `lib/wanderer_app/repositories/map_system_repo.ex`
- `lib/wanderer_app/repositories/character_repo.ex`

#### Implementation Example:
```elixir
# test/unit/repositories/access_list_repo_test.exs
defmodule WandererApp.AccessListRepoTest do
  use WandererApp.DataCase
  alias WandererApp.AccessListRepo

  describe "get/2" do
    test "returns access list with relationships" do
      acl = insert(:access_list)
      member = insert(:access_list_member, access_list_id: acl.id)
      
      assert {:ok, result} = AccessListRepo.get(acl.id, [:members])
      assert result.id == acl.id
      assert length(result.members) == 1
    end
    
    test "returns error for invalid id" do
      assert {:error, :not_found} = AccessListRepo.get("invalid-id")
    end
    
    test "returns error for non-existent id" do
      assert {:error, :not_found} = AccessListRepo.get(Ecto.UUID.generate())
    end
  end

  describe "list/1" do
    test "returns all access lists" do
      acl1 = insert(:access_list)
      acl2 = insert(:access_list)
      
      {:ok, results} = AccessListRepo.list()
      assert length(results) == 2
      assert Enum.map(results, & &1.id) |> Enum.sort() == 
        [acl1.id, acl2.id] |> Enum.sort()
    end
    
    test "returns empty list when no access lists exist" do
      {:ok, results} = AccessListRepo.list()
      assert results == []
    end
  end
end
```

### 1.3 Basic Ash API Resource Testing
**Estimated Coverage Gain: 2-3%**
**Implementation Effort: Medium (3-5 days)**

#### Priority Resources:
- `lib/wanderer_app/api/character.ex`
- `lib/wanderer_app/api/map.ex`
- `lib/wanderer_app/api/map_system.ex`
- `lib/wanderer_app/api/access_list.ex`

#### Implementation Example:
```elixir
# test/unit/api/character_test.exs
defmodule WandererApp.Api.CharacterTest do
  use WandererApp.DataCase
  alias WandererApp.Api.Character

  describe "create/1" do
    test "creates character with valid attributes" do
      user = insert(:user)
      attrs = %{
        eve_id: "123456789",
        name: "Test Character",
        corporation_id: "987654321",
        corporation_name: "Test Corp",
        user_id: user.id
      }
      
      assert {:ok, character} = Character.create(attrs)
      assert character.eve_id == "123456789"
      assert character.name == "Test Character"
      assert character.user_id == user.id
    end
    
    test "validates required fields" do
      assert {:error, %Ash.Error.Invalid{}} = Character.create(%{})
    end
    
    test "validates unique eve_id" do
      insert(:character, eve_id: "123456789")
      
      attrs = %{eve_id: "123456789", name: "Duplicate Character"}
      assert {:error, %Ash.Error.Invalid{}} = Character.create(attrs)
    end
  end

  describe "update/2" do
    test "updates character attributes" do
      character = insert(:character)
      
      assert {:ok, updated} = Character.update(character, %{name: "Updated Name"})
      assert updated.name == "Updated Name"
      assert updated.id == character.id
    end
    
    test "validates update constraints" do
      character = insert(:character)
      other_character = insert(:character, eve_id: "999999999")
      
      # Try to update to existing eve_id
      assert {:error, %Ash.Error.Invalid{}} = 
        Character.update(character, %{eve_id: "999999999"})
    end
  end

  describe "by_eve_id/1" do
    test "finds character by eve_id" do
      character = insert(:character, eve_id: "123456789")
      
      assert {:ok, found} = Character.by_eve_id("123456789")
      assert found.id == character.id
    end
    
    test "returns error for non-existent eve_id" do
      assert {:error, :not_found} = Character.by_eve_id("999999999")
    end
  end
end
```

---

## Phase 2: Core Business Logic (Week 3-5)
**Target: 22% → 25% (+3% increase)**

### 2.1 Character Management Testing
**Estimated Coverage Gain: 1-2%**
**Implementation Effort: High (5-7 days)**

#### Priority Files:
- `lib/wanderer_app/character/tracker.ex`
- `lib/wanderer_app/character/tracker_manager_impl.ex`

#### Implementation Example:
```elixir
# test/unit/character/tracker_test.exs
defmodule WandererApp.Character.TrackerTest do
  use WandererApp.DataCase
  alias WandererApp.Character.Tracker
  
  import Mox
  setup :verify_on_exit!

  describe "start_link/1" do
    test "starts tracker with valid character" do
      character = insert(:character)
      
      assert {:ok, pid} = Tracker.start_link(character: character)
      assert is_pid(pid)
      assert Process.alive?(pid)
    end
    
    test "returns error for invalid character" do
      assert {:error, :invalid_character} = Tracker.start_link(character: nil)
    end
  end

  describe "get_location/1" do
    test "returns current location" do
      character = insert(:character)
      {:ok, pid} = Tracker.start_link(character: character)
      
      # Mock ESI response
      WandererApp.Esi.Mock
      |> expect(:get_character_location, fn _eve_id ->
        {:ok, %{solar_system_id: 30000142}}
      end)
      
      assert {:ok, location} = Tracker.get_location(pid)
      assert location.solar_system_id == 30000142
    end
    
    test "handles ESI API errors" do
      character = insert(:character)
      {:ok, pid} = Tracker.start_link(character: character)
      
      WandererApp.Esi.Mock
      |> expect(:get_character_location, fn _eve_id ->
        {:error, :timeout}
      end)
      
      assert {:error, :timeout} = Tracker.get_location(pid)
    end
  end

  describe "update_location/2" do
    test "updates character location" do
      character = insert(:character)
      {:ok, pid} = Tracker.start_link(character: character)
      
      new_location = %{solar_system_id: 30000144}
      assert :ok = Tracker.update_location(pid, new_location)
      
      # Verify state was updated
      assert {:ok, location} = Tracker.get_location(pid)
      assert location.solar_system_id == 30000144
    end
  end
end
```

### 2.2 Map Operations Testing
**Estimated Coverage Gain: 1-2%**
**Implementation Effort: High (5-7 days)**

#### Priority Files:
- `lib/wanderer_app/map/operations/structures.ex`
- `lib/wanderer_app/map/map_manager.ex`

#### Implementation Example:
```elixir
# test/unit/map/operations/structures_test.exs
defmodule WandererApp.Map.Operations.StructuresTest do
  use WandererApp.DataCase
  alias WandererApp.Map.Operations.Structures

  describe "add_structure/3" do
    test "adds structure to map system" do
      map = insert(:map)
      system = insert(:map_system, map_id: map.id)
      
      structure_data = %{
        name: "Test Citadel",
        type_id: 35832,
        solar_system_id: system.solar_system_id
      }
      
      assert {:ok, structure} = Structures.add_structure(map.id, system.id, structure_data)
      assert structure.name == "Test Citadel"
      assert structure.type_id == 35832
    end
    
    test "validates structure data" do
      map = insert(:map)
      system = insert(:map_system, map_id: map.id)
      
      invalid_data = %{name: ""}
      
      assert {:error, :invalid_structure_data} = 
        Structures.add_structure(map.id, system.id, invalid_data)
    end
    
    test "returns error for non-existent system" do
      map = insert(:map)
      
      structure_data = %{name: "Test Citadel", type_id: 35832}
      
      assert {:error, :system_not_found} = 
        Structures.add_structure(map.id, "invalid-system-id", structure_data)
    end
  end

  describe "remove_structure/3" do
    test "removes structure from map system" do
      map = insert(:map)
      system = insert(:map_system, map_id: map.id)
      structure = insert(:map_system_structure, map_system_id: system.id)
      
      assert :ok = Structures.remove_structure(map.id, system.id, structure.id)
      
      # Verify structure was removed
      assert {:error, :not_found} = 
        WandererApp.Api.MapSystemStructure.by_id(structure.id)
    end
  end
end
```

### 2.3 External Events Testing
**Estimated Coverage Gain: 1%**
**Implementation Effort: Medium (3-4 days)**

#### Priority Files:
- `lib/wanderer_app/external_events/event.ex`
- `lib/wanderer_app/external_events/json_api_formatter.ex`

#### Implementation Example:
```elixir
# test/unit/external_events/event_test.exs
defmodule WandererApp.ExternalEvents.EventTest do
  use WandererApp.DataCase
  alias WandererApp.ExternalEvents.Event

  describe "create/1" do
    test "creates event with valid attributes" do
      attrs = %{
        type: :add_system,
        map_id: Ecto.UUID.generate(),
        payload: %{system_id: "123", name: "Test System"}
      }
      
      assert {:ok, event} = Event.create(attrs)
      assert event.type == :add_system
      assert event.payload["system_id"] == "123"
    end
    
    test "validates required fields" do
      assert {:error, %Ash.Error.Invalid{}} = Event.create(%{})
    end
    
    test "validates event type" do
      attrs = %{
        type: :invalid_type,
        map_id: Ecto.UUID.generate(),
        payload: %{}
      }
      
      assert {:error, %Ash.Error.Invalid{}} = Event.create(attrs)
    end
  end

  describe "serialize/1" do
    test "serializes event to JSON" do
      event = insert(:event, type: :add_system, payload: %{system_id: "123"})
      
      {:ok, json} = Event.serialize(event)
      
      assert json["type"] == "add_system"
      assert json["payload"]["system_id"] == "123"
      assert json["timestamp"] != nil
    end
  end
end
```

---

## Phase 3: Consolidation & Optimization (Week 6+)
**Target: 25%+ → 30%**

### 3.1 ESI Client Core Functions
**Estimated Coverage Gain: 1-2%**
**Implementation Effort: High (4-6 days)**

#### Priority Files:
- `lib/wanderer_app/esi/api_client.ex` (focus on most-used functions)
- `lib/wanderer_app/esi/token_manager.ex`

### 3.2 Complex Integration Testing
**Estimated Coverage Gain: 1-2%**
**Implementation Effort: Medium (3-4 days)**

#### Fill gaps in existing integration tests
#### Add end-to-end workflow tests

---

## Implementation Guidelines

### Test Organization
```
test/
├── unit/
│   ├── utils/           # Utility module tests
│   ├── repositories/    # Repository layer tests
│   ├── api/            # Ash API resource tests
│   ├── character/      # Character management tests
│   ├── map/            # Map operations tests
│   └── external_events/ # External events tests
├── integration/         # Existing integration tests
└── support/            # Test helpers and utilities
```

### Test Patterns to Follow

#### 1. Unit Test Structure
```elixir
defmodule WandererApp.Module.SubModuleTest do
  use WandererApp.DataCase  # or ExUnit.Case for pure functions
  alias WandererApp.Module.SubModule
  
  describe "function_name/arity" do
    test "success case description" do
      # Arrange
      # Act
      # Assert
    end
    
    test "error case description" do
      # Arrange
      # Act
      # Assert
    end
  end
end
```

#### 2. Mock Usage
```elixir
# Use existing mock patterns
import Mox
setup :verify_on_exit!

# Mock external services
WandererApp.Esi.Mock
|> expect(:function_name, fn args -> {:ok, result} end)
```

#### 3. Factory Usage
```elixir
# Use existing factory patterns
user = insert(:user)
character = insert(:character, user_id: user.id)
map = insert(:map, owner_id: user.id)
```

### Quality Standards

#### Coverage Targets
- **Utility modules**: 95%+ coverage
- **Repository layer**: 85%+ coverage
- **API resources**: 80%+ coverage
- **Business logic**: 75%+ coverage

#### Test Quality
- Follow AAA pattern (Arrange-Act-Assert)
- Test both success and error cases
- Use descriptive test names
- Mock external dependencies
- Ensure test isolation

### Success Metrics

#### Weekly Targets
- **Week 1**: 20% coverage (+2.4%)
- **Week 2**: 22% coverage (+4.4%)
- **Week 3**: 23% coverage (+5.4%)
- **Week 4**: 24% coverage (+6.4%)
- **Week 5**: 25% coverage (+7.4%)

#### Quality Metrics
- All tests pass consistently
- No flaky tests introduced
- Test execution time < 2 minutes
- No reduction in existing coverage

### Risk Mitigation

#### High-Risk Areas
1. **GenServer Testing** - Complex state management
2. **External API Mocking** - Service dependencies
3. **Database Transactions** - Isolation issues

#### Mitigation Strategies
1. **Start Simple** - Test public APIs first
2. **Use Existing Patterns** - Follow established test patterns
3. **Incremental Approach** - Build complexity gradually
4. **Continuous Validation** - Run tests frequently

### Resource Requirements

#### Time Estimates
- **Phase 1**: 40-50 hours (2 weeks)
- **Phase 2**: 60-70 hours (3 weeks)
- **Phase 3**: 40-50 hours (2+ weeks)

#### Tools and Infrastructure
- **Existing**: ExUnit, Mox, ExMachina, DataCase
- **Coverage**: ExCoveralls for reporting
- **CI/CD**: GitHub Actions for automated testing

### Monitoring and Validation

#### Daily Checks
- Run `mix test --cover` to verify coverage increase
- Check for test failures or flaky tests
- Validate test execution time

#### Weekly Reviews
- Review coverage reports
- Identify coverage gaps
- Adjust priorities based on progress

#### Success Criteria
- **Primary**: Achieve 25%+ test coverage
- **Secondary**: Maintain test quality and execution speed
- **Tertiary**: Establish foundation for future coverage growth

---

## Conclusion

This implementation plan provides a strategic path to increase test coverage from 17.6% to 25%+ through focused effort on high-impact areas. The plan emphasizes:

1. **Quick wins** through utility and repository testing
2. **Core business logic** coverage for critical functionality
3. **Sustainable practices** that enable future growth
4. **Quality maintenance** throughout the process

By following this plan, the project will achieve meaningful coverage improvement while building a solid foundation for continued testing excellence.

### Next Steps

1. **Review and approve** this implementation plan
2. **Set up tracking** for coverage metrics
3. **Begin Phase 1** with utility module testing
4. **Establish rhythm** of daily coverage checks
5. **Monitor progress** and adjust as needed

The plan is designed to be flexible and can be adjusted based on team capacity and priorities while maintaining the core goal of achieving 25%+ test coverage.
# API Breaking Changes Workflow

## Overview

This document explains how the API breaking changes detection workflow works in the Wanderer project and provides guidance on handling required breaking changes.

## How the Workflow Works

### 1. Automatic Detection

The API breaking changes workflow runs automatically on every pull request that modifies API-related files:

- Controllers in `lib/wanderer_app_web/controllers/`
- API schemas in `lib/wanderer_app_web/schemas/`
- API specifications in `lib/wanderer_app_web/api_spec.ex`
- Router definitions
- API contexts

### 2. What is Detected

The workflow detects the following breaking changes:

#### Endpoint Changes
- **Endpoint removed** - An existing API endpoint is no longer available
- **Method removed** - An HTTP method (GET, POST, etc.) is removed from an endpoint

#### Parameter Changes
- **Required parameter added** - A new required parameter is added to an existing endpoint
- **Parameter removed** - An existing parameter is removed
- **Parameter type changed** - The data type of a parameter changes

#### Response Changes
- **Response removed** - A response code is no longer returned
- **Response type changed** - The structure or type of a response changes
- **Required property added** - A new required field is added to a response
- **Property removed** - An existing response field is removed
- **Property type changed** - The data type of a response field changes

#### Schema Changes
- **Enum value removed** - A value is removed from an enum type
- **Discriminator changed** - Changes to discriminator fields in polymorphic types

### 3. Workflow Process

1. **OpenAPI Spec Generation**
   - The workflow generates OpenAPI specifications for both the main branch and the PR branch
   - Uses `mix openapi.export` to create JSON specifications

2. **Comparison**
   - The `check_api_breaking_changes.exs` script compares the two specifications
   - Identifies all changes and filters for breaking changes

3. **Reporting**
   - If breaking changes are detected:
     - The workflow fails
     - A comment is added to the PR listing the breaking changes
     - The OpenAPI specs are uploaded as artifacts for manual review

## Handling Breaking Changes

### When Breaking Changes are Required

Sometimes breaking changes are necessary for:
- Security fixes
- Major feature additions
- Removing deprecated functionality
- Fixing fundamental design issues

### Best Practices for Breaking Changes

1. **API Versioning**
   - Consider introducing a new API version (e.g., `/api/v2/`) instead of breaking `/api/v1/`
   - Maintain both versions during a transition period

2. **Deprecation Process**
   - Mark endpoints/fields as deprecated before removal
   - Provide clear deprecation notices in responses
   - Set a deprecation timeline (recommended: 3-6 months)

3. **Communication**
   - Document all breaking changes in the changelog
   - Notify API consumers well in advance
   - Provide migration guides

4. **Gradual Migration**
   ```elixir
   # Example: Adding a required field gradually
   
   # Step 1: Add as optional field
   field :new_field, :string, required: false
   
   # Step 2: Log warnings when field is missing
   # Step 3: After transition period, make required
   field :new_field, :string, required: true
   ```

### Bypassing the Check (When Absolutely Necessary)

If you must introduce a breaking change:

1. **Document the Change**
   - Add a detailed explanation in your PR description
   - Include justification for why the breaking change is necessary
   - Describe the migration path for API consumers

2. **Update API Version**
   - Consider bumping the API version in `lib/wanderer_app_web/api_spec.ex`
   - Follow semantic versioning principles

3. **Manual Override**
   - A maintainer can merge the PR despite the failing check
   - This should be done only after careful review

## Examples

### Adding a New Required Field (Breaking)

```diff
defmodule MySchema do
  embedded_schema do
    field :existing_field, :string
+   field :new_required_field, :string, required: true
  end
end
```

**Better approach**: Add as optional first, then make required later:

```diff
# Phase 1: Add as optional
+ field :new_required_field, :string, required: false

# Phase 2: After deprecation period
- field :new_required_field, :string, required: false
+ field :new_required_field, :string, required: true
```

### Changing Response Structure (Breaking)

```diff
# Before
%{
  "data": {
    "id": 123,
    "name": "Example"
  }
}

# After (Breaking!)
%{
  "result": {
    "identifier": 123,
    "title": "Example"
  }
}
```

**Better approach**: Support both formats temporarily:

```elixir
# Return both old and new format during transition
%{
  "data": {...},      # Deprecated
  "result": {...}     # New format
}
```

## Running the Check Locally

To test for breaking changes before pushing:

```bash
# Generate current spec
mix openapi.export --output current-spec.json

# Make your changes, then generate new spec
mix openapi.export --output new-spec.json

# Run the comparison
elixir scripts/check_api_breaking_changes.exs current-spec.json new-spec.json
```

## Maintaining API Stability

1. **Think Before Adding**
   - Consider if new fields should be required
   - Design for extensibility

2. **Use Flexible Types**
   - Prefer objects over primitives for future extensibility
   - Use nullable fields when appropriate

3. **Version Early**
   - If you anticipate multiple breaking changes, start a new API version

4. **Test Thoroughly**
   - Include tests for backward compatibility
   - Test with actual API clients when possible

## Getting Help

If you're unsure whether a change is breaking or how to handle it:

1. Run the breaking changes check locally
2. Consult with the team in the PR discussion
3. Review similar past changes in the git history
4. When in doubt, assume it's breaking and plan accordingly
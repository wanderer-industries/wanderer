In lib/wanderer_app/test_monitor.ex around lines 11 to 25, your ExUnitFormatter
module currently only implements init/1 and handle_cast/2, but the
ExUnit.Formatter behaviour requires additional callbacks: handle_call/3,
handle_info/2, and terminate/2. To fix this, add the @behaviour ExUnit.Formatter
declaration at the top of the module and implement the missing callbacks with
appropriate stub implementations: handle_call/3 should reply with {:reply, :ok,
state}, handle_info/2 should return {:noreply, state}, and terminate/2 should
return :ok. This will prevent runtime errors and ensure proper message handling.

In priv/repo/migrations/20250714071923_fix_webhook_secret_column.exs around
lines 12 to 22, the migration adds a new plain text secret column and removes
the encrypted one but lacks a data migration step to transfer existing encrypted
secrets to the new column. To fix this, add a data migration step after adding
the new column that decrypts the existing encrypted_secret values and populates
the new secret column accordingly, ensuring existing data is preserved. Also,
review the security implications of storing secrets in plain text and consider
encrypting the new column or applying environment-specific handling.

In .github/workflows/test.yml around lines 44 to 51, the GitHub Actions cache
step uses the outdated version actions/cache@v3. Update the version to the
latest stable release, such as actions/cache@v3.1 or the current recommended
version, by modifying the uses field accordingly to ensure you are using the
most recent improvements and fixes.

In lib/wanderer_app_web/controllers/plugs/json_api_performance_monitor.ex at
line 39, the variable duration is calculated but not used, causing an unused
variable warning. To fix this, include the duration variable in the telemetry
event emission so it is utilized properly and the warning is resolved.

In lib/wanderer_app_web/controllers/api/map_systems_connections_controller.ex
around lines 81 to 101, add input validation to ensure the map_id parameter is
in the expected format before processing it, returning an error response if
invalid. Additionally, implement rate limiting on the show action to prevent
abuse of this potentially expensive operation, using a plug or middleware to
limit the number of requests per client within a time window.

In lib/wanderer_app_web/controllers/api/map_systems_connections_controller.ex
between lines 125 and 155, the format_system and format_connection functions
include fields like tag, description, labels, inserted_at, updated_at, and
ship_size_type that are missing from the OpenAPI schema documentation (lines
42-74). To fix this inconsistency, either remove these extra fields from the
formatting functions to match the schema or update the OpenAPI schema to include
these fields so the documentation accurately reflects the actual API response.

In lib/wanderer_app_web/controllers/api/map_systems_connections_controller.ex
lines 103 to 123, the current error handling masks important errors with a
catch-all clause and uses two separate Ash.read! calls that may raise unhandled
exceptions. Refactor to replace Ash.read! with Ash.read to handle errors
explicitly without exceptions, remove the catch-all rescue clause to avoid
masking errors, and optimize by combining the queries or using Ash's preloading
features to load systems and connections in a single query for better
performance.

In lib/wanderer_app/enhanced_performance_monitor.ex around lines 11 to 13, the
GenServer start_link function lacks supervision and error handling. Refactor the
code to include a proper supervisor module that starts this GenServer under a
supervision tree. Also, add error handling to manage start_link failures
gracefully, such as returning appropriate error tuples or logging errors, to
ensure production readiness.

In lib/wanderer_app/api/access_list_member.ex at lines 121 to 124, the
access_list association is marked public without any authorization, risking
sensitive data exposure. To fix this, create a policy module like
AccessListPolicy or integrate an authorization library such as Bodyguard or
Canada to enforce access controls on this association. Then update the relevant
controller or resolver to invoke this policy before rendering the access_list
data, ensuring only authorized users can access it.

In TEST_COVERAGE_IMPLEMENTATION_PLAN.md around lines 539 to 543, the time
estimates for Phase 2 are too optimistic given the complexity of testing core
business logic such as GenServers and external API integrations. Revise the
Phase 2 time estimates to allocate more hours, reflecting the additional effort
required for these complex tests, ensuring the estimates are more conservative
and realistic.

In lib/wanderer*app_web/controllers/plugs/check_json_api_auth.ex around lines
116 to 141, the test token validation creates users with predictable hash
patterns that could be exploited. To fix this, replace the predictable
"test_hash*" concatenation with a securely generated random string or token for
the user hash, such as using a cryptographically secure random generator,
ensuring test tokens remain secure while preserving test functionality.

In lib/wanderer_app_web/open_api.ex around lines 78 to 79, the OpenAPI schema
references a MapSystem that does not exist, causing a missing schema definition
error. To fix this, either create a new module WandererApp.Api.MapSystem using
Ash.Resource with AshJsonApi.Resource extension and set its json_api type to
"map_systems", or update the OpenAPI reference at these lines to point to an
existing schema like MapSystemStructure or MapSystemComment, or alternatively
add a manual schema definition for MapSystem in the OpenAPI spec.

In the Makefile around lines 56, 60, 64, and 68, each test target (test-smoke,
test-comprehensive, test-performance, test-fast) currently runs the
automated_test_runner.exs script without checking if the script exists. Add a
file existence check before invoking the elixir command for each target, and if
the script is missing, print a clear error message and exit with a failure code
to fail fast.

In lib/wanderer_app/api/map_webhook_subscription.ex at line 125, the
rotate_secret action currently accepts the :secret attribute, which conflicts
with the intention to generate a new secret automatically. Remove the accept
[:secret] clause from the rotate_secret action to prevent users from supplying
their own secret and ensure that only securely generated secrets are used during
rotation.

In lib/wanderer_app/api/map_webhook_subscription.ex around lines 19 to 21, the
webhook secrets are currently stored unencrypted, posing a security risk. Update
the implementation to encrypt these secrets at rest using a strong algorithm
like AES-256, managing encryption keys outside the database via environment
variables or a secrets manager. Modify the code to decrypt secrets only when
needed for webhook operations, avoid logging secrets, and ensure all database
connections use TLS/SSL. Additionally, update comments to document these
security practices and consider rotating secrets regularly and isolating them in
a dedicated table or schema.

In lib/mix/tasks/test_health_dashboard.ex at lines 418, 596, 612, and 630, the
code uses Enum.map followed by Enum.join to concatenate test names, which
creates intermediate lists and impacts performance. Replace these instances with
Enum.map_join/3 to combine mapping and joining in a single pass, improving
efficiency. Update each line to use Enum.map_join with the appropriate separator
and mapping function instead of separate map and join calls.

In lib/wanderer_app/map/map_audit.ex at line 11, the module attribute @logger is
defined but not used anywhere in the code. Remove the line defining @logger to
clean up unused code and avoid confusion.

In lib/mix/tasks/quality_progressive_check.ex around lines 81 to 92, the code
runs the "mix quality_report" command but does not check the command's exit
status, which can lead to silent failures. Modify the code to capture and check
the exit status returned by System.cmd, and handle non-zero exit codes
explicitly by logging an error or returning an empty metrics map to indicate
failure.

In lib/wanderer_app_web/plugs/security_audit.ex lines 102 to 124, the
get_peer_ip function trusts the x-forwarded-for header without validation,
risking IP spoofing. To fix this, implement a whitelist of trusted proxy IPs and
only accept the x-forwarded-for header if the request comes from a trusted
proxy. Otherwise, fall back to using the direct remote_ip from the connection.
This ensures the IP extracted is reliable and not spoofed via headers.

In lib/wanderer_app_web/plugs/content_security.ex around lines 296 to 308, the
function check_upload_rate_limit has an unused parameter user_id causing a
warning. To fix this, rename the parameter to \_user_id to indicate it is
intentionally unused and suppress the warning.

In lib/wanderer_app_web/controllers/map_system_api_controller.ex around lines
462 to 468, the update action lacks verification that the system belongs to the
requested map, which could allow unauthorized updates. Add a check after
fetching the system to confirm its association with the map identified in the
request parameters before proceeding with the update. If the system does not
belong to the map, return an appropriate error response to prevent unauthorized
modifications.

In lib/wanderer_app/api/map_connection.ex around lines 180 to 210, the
belongs_to :map relationship is publicly readable and writable, allowing any
authenticated client to access or modify map_id on MapConnection records without
restriction. To fix this, add a policies block that restricts read, create,
update, and destroy actions to only the map owner by authorizing when actor.id
equals resource.map.owner_id. Alternatively, if preferred, disable public access
to the map relationship entirely by removing or setting public? and
attribute_writable? to false.

In lib/wanderer_app/repositories/map_character_settings_repo.ex around lines 139
to 144, the destroy! function returns the original settings on success, which is
inconsistent with other bang functions that typically return the destroyed
resource or raise on error. Update the function to return the destroyed resource
or a more appropriate value indicating successful destruction, ensuring
consistency with other bang functions and avoiding confusion about the resource
state.

In lib/wanderer_app/map/operations/duplication.ex at line 16, remove the unused
import of Ash.Query since the code already uses the fully qualified
Ash.Query.filter/2 calls. Deleting this import will resolve the pipeline failure
caused by the unused import warning.

In lib/wanderer_app/map/operations/duplication.ex around lines 36 to 58, the
duplicate_map/3 function performs multiple database writes without wrapping them
in a transaction, risking partial updates on failure. Refactor the function to
build an Ash.Multi that includes all the copy steps as actions within the
transaction, then execute this multi via your API's transaction/1 function. This
ensures atomicity by rolling back all changes if any step fails.

In lib/wanderer_app_web/api_router_helpers.ex around lines 23 to 30, the code
uses String.to_integer/1 which raises an error if the input string is invalid.
Replace these calls with a new helper function parse_integer/2 that safely
parses the string using Integer.parse/1 and returns a default value if parsing
fails. Implement parse_integer/2 as described, then use it to parse "page" and
"per_page" parameters with appropriate defaults instead of String.to_integer/1.

In lib/wanderer_app_web/api_router_helpers.ex around lines 37 to 43, the integer
parsing for JSON:API pagination parameters lacks safety checks. Update the
JSON:API pagination code to parse the "number" and "size" parameters using safe
integer parsing methods similar to the existing code, providing default values
and ensuring the size does not exceed the maximum page size. This will prevent
errors from invalid input and maintain consistency.

In lib/wanderer_app_web/api_router_helpers.ex around lines 8 to 10, the function
version_specific_action/2 currently converts the version string directly into an
atom without validating the version format, which can lead to invalid atom
names. Add validation to ensure the version string matches the expected format
(e.g., digits separated by dots) before converting it. If the format is invalid,
handle it gracefully by either returning an error or a default atom to prevent
creating invalid atoms.

In lib/mix/tasks/test_maintenance.ex around lines 517 to 527, the file write
operations use File.write! which will crash the task if writing fails. Replace
File.write! with File.write and add error handling to check the result of each
write operation. Handle errors gracefully by logging an appropriate message or
taking corrective action instead of letting the task crash.

In lib/wanderer_app_web/plugs/api_versioning.ex around lines 209 to 225, the
compare_versions function assumes version strings have exactly two parts and
appends ".0" to them, which is fragile and can cause incorrect comparisons. To
fix this, modify the function to handle version strings of varying lengths
properly without appending ".0". Use Version.parse! directly on the original
version strings if they are valid semantic versions, or normalize them to a
standard format before parsing. Also, instead of rescuing all errors and
returning :eq silently, handle parse errors explicitly, possibly by returning an
error or a defined fallback, to avoid masking real issues.

In lib/wanderer_app_web/open_api_v1_spec.ex from lines 17 to 541, there are many
private functions implementing the OpenAPI spec that are currently unused
because the spec/0 function delegates to WandererAppWeb.OpenApi.spec(). To fix
this, either remove all these unused private functions if the spec is generated
elsewhere, or update the spec/0 function to call generate_spec_manually/0 to use
this manual implementation as intended.

In lib/wanderer_app/telemetry.ex lines 177 to 204, the
measure_endpoint_performance/2 function currently uses placeholder timing logic
without making real HTTP calls to the specified endpoint. To fix this, replace
the placeholder with actual HTTP request calls to the given endpoint_name inside
the Enum.map loop, measuring the duration of each request accurately. Use a
suitable HTTP client library to perform the requests and calculate the elapsed
time for each call, then compute the average, max, and min durations as before.

In lib/wanderer_app_web/plugs/response_sanitizer.ex around lines 245 to 256, the
current HTML sanitization uses regex replacements which are error-prone and may
miss XSS attack vectors. Replace this regex-based approach with a proper HTML
sanitization library such as html_sanitize_ex or phoenix_html's sanitization
functions to ensure robust and comprehensive protection against XSS. Update the
sanitize_html_content function to utilize the chosen library's API for parsing
and cleaning the HTML content safely.

In lib/wanderer_app_web/plugs/response_sanitizer.ex between lines 99 and 111,
the code uses Enum.map followed by Enum.join to process and join the base_policy
list. To improve efficiency, replace this pattern with Enum.map_join, which
combines mapping and joining into a single pass. Modify the code to use
Enum.map_join with the same mapping function and the join separator "; " to
achieve the same result more efficiently.

In lib/mix/tasks/test.performance.ex around lines 319 to 328, the if condition
uses a negated check with 'not Enum.empty?(report.regressions)'. Refactor this
to use a positive condition by checking 'Enum.any?(report.regressions)' instead.
This improves readability by avoiding negation in the if statement.

In lib/wanderer_app_web/controllers/api/health_controller.ex lines 358 to 371,
the check_migrations_status/0 function currently returns a hardcoded
"up_to_date" status without verifying migration status. Update this function to
call Ecto.Migrator.migrations/2 with the appropriate repo and migrations path,
then check if all migrations have been run. Return ready: true and status:
"up_to_date" only if all migrations are applied; otherwise, return ready: false
with details about pending migrations or errors.

In lib/wanderer_app_web/controllers/api/health_controller.ex around lines 524 to
528, the get_cpu_usage/0 function currently returns a hardcoded 0.0, providing
no real CPU usage data. To fix this, implement actual CPU usage monitoring by
using the :cpu_sup or :os_mon Erlang application to retrieve current CPU load
metrics and return that value instead of 0.0. Alternatively, if immediate
implementation is not feasible, open an issue to track this TODO for future
completion.

In lib/wanderer_app_web/controllers/api/health_controller.ex at line 173,
replace the deprecated call to System.get_pid() with :os.getpid() to obtain the
current process ID using the recommended function.

In lib/wanderer_app/api/map_user_settings.ex around lines 17 to 20 and line 99,
the primary key configuration in the JSON:API setup uses [:id], but the resource
defines a composite primary key [:map_id, :user_id]. To fix this inconsistency,
update the primary_key block to use the composite keys [:map_id, :user_id] to
match the resource identity, or alternatively, adjust the resource to use a
single :id key if that is the intended design. Ensure both the JSON:API
configuration and the resource definition align on the primary key structure.

In lib/wanderer_app_web/plugs/request_validator.ex at lines 241 to 244, the
function validate_param_value/5 has an unused parameter key that is not used in
the function body. Remove the key parameter from the function definition so it
only accepts value, max_length, max_depth, and current_depth, and update any
calls to this function accordingly.

In lib/wanderer_app_web/plugs/request_validator.ex at lines 236 to 239, the
function validate_param_value/5 has an unused parameter key that is not used in
the function body. Remove the key parameter from the function definition so it
only accepts value, max_length, max_depth, and current_depth, and update any
calls to this function accordingly.

In lib/wanderer_app_web/plugs/request_validator.ex around lines 222 to 234, the
function validate_param_value has unused variables key, max_depth, and
current_depth causing pipeline warnings. Remove these unused variables from the
function parameters and update the function body accordingly to eliminate the
warnings.

In lib/wanderer_app_web/plugs/request_validator.ex around lines 222 to 234, the
function validate_param_value has unused variables key, max_depth, and
current_depth causing pipeline warnings. Remove these unused variables from the
function parameters and update the function body accordingly to eliminate the
warnings.

In lib/wanderer_app/monitoring/api_health_monitor.ex around lines 37 to 40, the
timeout values larger than 9999 should use underscores to improve readability.
Update the numeric literals 10000 to 10_000 by inserting underscores
appropriately without changing their values.

In lib/wanderer_app/monitoring/api_health_monitor.ex around lines 37 to 40, the
timeout values larger than 9999 should use underscores to improve readability.
Update the numeric literals 10000 to 10_000 by inserting underscores
appropriately without changing their values.

In lib/mix/tasks/ci_monitoring.ex at line 282, the numeric literal 60000 should
be rewritten using underscores for readability. Change 60000 to 60_000 to
improve clarity without affecting functionality.

In lib/mix/tasks/ci_monitoring.ex around lines 865 to 868, replace the current
use of Enum.map followed by Enum.join with a single call to Enum.map_join/3 to
improve performance. Use Enum.map_join to combine mapping and joining into one
operation by passing the separator and mapping function as arguments.

In lib/wanderer_app_web/api_router.ex around lines 426 to 432 and also lines 445
to 449, the code uses Phoenix.Conn functions without proper aliasing, causing
undefined module warnings. To fix this, add an alias for Phoenix.Conn at the top
of the module (e.g., alias Phoenix.Conn) and then update all Phoenix.Conn
function calls in these lines to use the aliased module name Conn instead of the
full Phoenix.Conn.

In lib/wanderer_app_web/api_router.ex from lines 42 to 400, the routing
functions route_v1_0, route_v1_1, and route_v1_2 have a lot of duplicated code
for matching HTTP methods and paths to controller actions. To fix this, extract
the route definitions for each version into a centralized data structure like a
map or list of tuples that specify method, path pattern, controller, action, and
enhancements. Then implement a generic routing function that looks up the route
based on the connection and version, and dispatches accordingly. This will
reduce duplication and make it easier to maintain and extend routing logic.

In lib/wanderer_app_web/api_router.ex from lines 42 to 400, the routing
functions route_v1_0, route_v1_1, and route_v1_2 have a lot of duplicated code
for matching HTTP methods and paths to controller actions. To fix this, extract
the route definitions for each version into a centralized data structure like a
map or list of tuples that specify method, path pattern, controller, action, and
enhancements. Then implement a generic routing function that looks up the route
based on the connection and version, and dispatches accordingly. This will
reduce duplication and make it easier to maintain and extend routing logic.

In lib/wanderer_app_web/api_router.ex at line 17, remove the import statement
for WandererAppWeb.ApiRouterHelpers because it is unused and the module is
undefined, which helps clean up the code and avoid potential errors.

In .github/workflows/archive/test-maintenance.yml at lines 56, 70, 114, 149,
163, 286, 322, 336, and 384, update all instances of actions/cache@v3 to
actions/cache@v4 to use the latest supported version of the GitHub Action and
ensure proper workflow execution.

In .github/workflows/archive/test-maintenance.yml around lines 97 to 98 and also
lines 202 to 203, the use of 'cat' to pipe the JSON file into 'jq' is
inefficient and triggers shellcheck warnings. Replace the 'cat' command with
input redirection by passing the file directly to 'jq' using the '<' operator,
for example, 'jq -r ... < test_metrics/latest_maintenance_analysis.json'. This
removes the unnecessary use of 'cat' and improves script efficiency.

In lib/wanderer_app/security_audit.ex from lines 161 to 204, the functions use
Ash.read!() which can raise exceptions but this behavior is neither handled nor
documented. To fix this, either update each function to use Ash.read() and
handle the {:ok, result} and {:error, error} tuples explicitly by logging errors
and returning {:error, :query_failed}, or add documentation to each function's
@doc block clearly stating that the function may raise exceptions if the query
fails.

In lib/wanderer_app/security_audit.ex at line 15, remove the unused aliases
User, Character, and Map from the alias statement, leaving only UserActivity to
clean up the imports and avoid unnecessary code.

In lib/wanderer_app/security_audit.ex between lines 29 and 54, the log_event
function currently returns :ok regardless of whether critical operations like
store_audit_entry succeed or fail. To fix this, add error handling around these
operations by capturing any errors they might return or raise. You can propagate
errors by returning {:error, reason} when failures occur or at minimum log the
errors for visibility. This ensures failures in audit logging are detected and
handled appropriately instead of being silently ignored.

In lib/wanderer_app/security_audit.ex around lines 358 to 369, the
sanitize_sensitive_data function only matches lowercase keywords and handles
flat strings, missing variations in case and nested data structures. Update the
function to perform case-insensitive matching for keywords like "password",
"token", and "secret" by normalizing the string before checking. Extend the
sanitization to recursively handle nested data structures such as maps and
lists, applying the same redaction rules. Also consider expanding the keyword
list to cover more sensitive terms as needed.

In lib/wanderer_app/security_audit.ex lines 225 to 265, improve error handling
by replacing String.to_existing_atom/1 with a safe conversion that does not
raise if the atom doesn't exist, handle potential Jason.encode! failures by
using a safe encoding method or rescuing errors, and modify the function to
return a clear success or error status instead of just logging errors and
falling back silently.

In lib/mix/tasks/quality*report.ex lines 109 to 138, the current error handling
uses a broad rescue clause that catches all exceptions with *. Refine this by
rescuing only specific exceptions relevant to System.cmd failures or runtime
errors, and add logging of the error details to aid debugging. Apply this
pattern to both get_compilation_metrics and count_compilation_warnings
functions, ensuring that unexpected errors are not silently ignored and are
properly logged.

In lib/mix/tasks/quality_report.ex around lines 311 to 333, the call to the
custom Mix task "test.coverage.summary" fails because the task is not defined.
Fix this by either implementing the Mix.Tasks.Test.Coverage.Summary module in
lib/mix/tasks/test/coverage/summary.ex or modify get_coverage_metrics/0 to check
if the custom task is loaded using Code.ensure_loaded?. If not loaded, fallback
to running an existing coverage command like "mix test --cover --formatter json"
and decode its output accordingly. Ensure the function returns coverage metrics
consistently and handles errors gracefully.

In lib/mix/tasks/quality_report.ex around lines 382 to 399, the function uses
the private Mix.Dep.loaded/1 function to get dependencies, which is discouraged.
Replace this call with a public Mix API method such as
Mix.Dep.load_on_environment/1 or another appropriate public function to retrieve
dependency information safely. Adjust the code to use the returned data
structure from the public API accordingly.

In .devcontainer/setup.sh around lines 34 to 38, the script changes to the
assets directory but does not return to the original directory, and the build
command after the echo statement is missing. Add the appropriate build command
(e.g., yarn build) after the echo "→ building assets" line, and then add a
command to change back to the previous directory (e.g., cd -) to ensure the
script continues in the correct location.

In lib/wanderer_app/api/access_list.ex lines 14 to 30, the JSON:API endpoints
expose full CRUD without authentication or authorization. Fix this by adding Ash
policies to restrict update and delete actions to owners or admins, and ensure
read actions filter accessible resources based on the caller. Additionally, in
lib/wanderer_app_web/router.ex, update the /api/v1 scope to pipe through an
authentication or ACL plug such as :api_acl or add a plug like
WandererAppWeb.Plugs.CheckJsonApiAuth to enforce authentication on these
endpoints.

In config/test.exs at lines 40-41, the pubsub_client is set to Phoenix.PubSub,
which bypasses the existing Mox mock Test.PubSubMock and may break test
isolation. Decide whether to keep using the mock or switch fully to the real
client. If keeping the mock, revert pubsub_client to Test.PubSubMock here. If
switching to the real client, update test/README.md to remove or revise Mox mock
instructions, and modify test/STANDARDS.md to reflect using Phoenix.PubSub with
proper test setup and cleanup to maintain isolation.

In config/test.exs at lines 34 to 35, remove the line that sets the environment
variable WANDERER_CHARACTER_API_DISABLED to false using System.put_env, as it is
redundant. The test configuration already explicitly sets character_api_disabled
to false via Application config, and the environment variable is not used in the
test suite. Deleting this line will simplify the test setup without affecting
functionality.

In lib/wanderer_app_web/controllers/plugs/check_json_api_auth.ex at line 13, the
alias Ecto.UUID is declared but not used anywhere in the file. Remove the line
"alias Ecto.UUID" to clean up unused imports and improve code clarity.

In lib/wanderer_app/application.ex at line 126, the list used in the condition
contains a duplicate value `true`. Remove the duplicate so the list only
includes unique values, for example changing it to [true, "true"] to avoid
redundancy.

In lib/wanderer_app/map/map_audit.ex lines 72 to 92, the function
get_combined_activity_query defines a security_query but does not use it,
causing unused variable warnings and incomplete functionality. To fix this,
combine the map_query and security_query results appropriately, such as by using
a union or merging their results depending on the query capabilities, and return
the combined query instead of just map_query. If combining is not feasible,
remove the security_query definition to eliminate the unused variable warning.

In lib/wanderer_app_web/controllers/api/events_controller.ex around lines 61 to
63, the format parameter is currently accepted without validation, but only
"jsonapi" and "legacy" are supported. Update the code to validate the format
parameter by using a case statement that matches only "legacy" or "jsonapi". If
the parameter is invalid, respond with a 400 Bad Request status and a JSON error
message indicating the supported formats. This ensures only valid formats
proceed and invalid ones return an appropriate error.

In lib/wanderer_app_web/controllers/api/events_controller.ex around lines 61 to
63, the format parameter is currently accepted without validation, but only
"jsonapi" and "legacy" are supported. Update the code to validate the format
parameter by using a case statement that matches only "legacy" or "jsonapi". If
the parameter is invalid, respond with a 400 Bad Request status and a JSON error
message indicating the supported formats. This ensures only valid formats
proceed and invalid ones return an appropriate error.

In lib/wanderer_app/api/map_system.ex around lines 84 to 92, the new string
attributes custom_name, description, tag, temporary_name, and labels currently
only have allow_nil? true set without any length or format validations. Add
appropriate validations for each attribute including length constraints (e.g.,
validate length with min and max values) and format checks if applicable, to
ensure inputs are neither too long nor malformed and comply with any
domain-specific rules.

In lib/wanderer_app/api/map_system.ex around lines 14 to 30, the JSON:API
configuration currently allows unrestricted filtering, sorting, and full CRUD
operations which may pose security risks. To fix this, explicitly define which
fields can be filtered and sorted instead of using derive_filter? and
derive_sort? with true. Additionally, implement access controls or rate limiting
on these routes to restrict usage and prevent abuse, ensuring only authorized
users can perform sensitive operations.

In lib/wanderer_app/map/operations/duplication.ex at line 146, the function
copy_single_connection/3 has an unused parameter system_mapping. Review the
function to determine if system_mapping should be used to update system
references within the copied connection. If so, modify the function to apply the
system_mapping to relevant fields in the new connection; otherwise, remove the
unused parameter to clean up the function signature.

In lib/wanderer_app_web/plugs/api_versioning.ex around lines 93 to 104, the
version detection by path currently hardcodes specific version strings, limiting
flexibility. Modify the pattern matching to accept any version string after
"api" in the path, removing the explicit version list check. This way, any
version string is captured and returned as {:ok, version}, deferring validation
to the validate_version/3 function.

I

In lib/wanderer_app_web/controllers/api/health_controller.ex around lines 467 to
475, the deep_check_json_api/0 function currently returns hardcoded JSON:API
compliance data without performing any real checks. To fix this, implement
actual verification logic that inspects the API's responses or configuration to
determine true compliance with the JSON:API specification, or alternatively, add
a TODO comment indicating that this function requires proper implementation in
the future.

In lib/wanderer_app_web/controllers/api/health_controller.ex around lines 477 to
484, the deep_check_external_services/0 function currently returns hardcoded
health status without verifying actual connectivity. Modify this function to
perform real checks by making HTTP requests or appropriate calls to the ESI API
and license service, then update the status, services_checked list, and
all_accessible flag based on the results of these checks.

In lib/wanderer_app/api/character.ex around lines 14 to 32, add a policies block
inside the json_api block to enforce authorization rules for the Character
resource. Define fine-grained permissions for each CRUD action (read, create,
update, destroy) based on user roles or scopes to prevent any authenticated user
from performing all operations indiscriminately. Also, review whether the
destroy route should remain exposed and remove it if not appropriate. Adjust the
policy definitions to align with your app's authorization requirements.

In lib/wanderer_app/api/character.ex lines 73 to 104, sensitive fields like
:access_token, :refresh_token, :character_owner_hash, :token_type, and
:expires_at are currently accepted in the public create action without
encryption or validation. Remove these sensitive fields from the public accept
list in the create action to restrict their setting to internal processes only.
Alternatively, if they must remain in the accept list, add them to the cloak do
attributes block to ensure they are encrypted at rest. Additionally, implement
validations for these token fields to check their format and length to prevent
malformed or malicious input.

In lib/wanderer_app/api/map.ex around lines 175 and 200, add validation to check
for the presence of context.actor before setting owner_id in the change
function; if context.actor is missing, add an error to the changeset indicating
authentication is required. Additionally, enable transactions on the duplicate
create action by adding transaction?: true to ensure that any errors in the
after_action hook roll back the new map creation, preventing incomplete
duplicates.

In lib/mix/tasks/quality_report.ex around lines 543 to 545, the function
format_json_report uses Jason.encode! which can raise an exception if the data
contains non-encodable values. Modify the function to use Jason.encode instead,
which returns {:ok, json} or {:error, reason}, then handle the error case
gracefully by either returning an error tuple or logging the issue, ensuring the
function does not raise exceptions on encoding failures.

ere’s a concrete refactor plan that removes the triple-copy boilerplate and lets you add new versions by editing a single table.

​Define a single data-table of routes + features

# lib/wanderer_app_web/api_router/routes.ex

defmodule WandererAppWeb.ApiRoutes do
@type verb :: :get | :post | :put | :patch | :delete
@type segment :: String.t() | atom()

@route_definitions %{
"1.0" => [
{:get, ~w(api maps), MapAPIController, :index_v1_0, []},
{:get, ~w(api maps :id), MapAPIController, :show_v1_0, []},
{:post, ~w(api maps), MapAPIController, :create_v1_0, []},
{:put, ~w(api maps :id), MapAPIController, :update_v1_0, []},
{:delete, ~w(api maps :id), MapAPIController, :delete_v1_0, []},
{:get, ~w(api characters), CharactersAPIController, :index_v1_0, []},
{:get, ~w(api characters :id), CharactersAPIController, :show_v1_0, []}
],

    "1.1" => [
      {:get,  ~w(api maps),                  MapAPIController,        :index_v1_1, ~w(filtering sorting pagination)},
      {:get,  ~w(api maps :id),              MapAPIController,        :show_v1_1,  ~w(sparse_fieldsets)},
      {:post, ~w(api maps),                  MapAPIController,        :create_v1_1, []},
      # …
    ],

    "1.2" => [
      {:get,  ~w(api maps),                  MapAPIController,        :index_v1_2,
        ~w(filtering sorting pagination includes)},
      {:post, ~w(api maps :id duplicate),    MapAPIController,        :duplicate_v1_2, []},
      # …
    ]

}

def table, do: @route_definitions
end
​Generic dispatcher (replaces route_v1_X trio)

# lib/wanderer_app_web/api_router.ex

defmodule WandererAppWeb.ApiRouter do
use Phoenix.Router
import WandererAppWeb.ApiRouterHelpers
alias WandererAppWeb.Plugs.ApiVersioning
alias WandererAppWeb.ApiRoutes

def call(conn, \_opts) do
version = conn.assigns[:api_version] || "1.2"
route_by_version(conn, version)
end

defp route_by_version(conn, version) do
routes = Map.get(ApiRoutes.table(), version, [])

    case Enum.find(routes, &match_route?(conn, &1)) do
      nil  -> send_not_supported_error(conn, version)
      {verb, path, ctrl, act, features} ->
        params = extract_path_params(conn.path_info, path)
        conn
        |> add_version_features(features, version)
        |> route_to_controller(ctrl, act, params)
    end

end

defp match_route?(%Plug.Conn{method: m, path_info: p}, {verb, segs, \_c, \_a, \_f}) do
verb_atom = m |> String.downcase() |> String.to_atom()
verb_atom == verb and path_match?(p, segs)
end

# simple segment matcher – atoms act as wildcards

defp path*match?([h|t],[s|rest]) when is_binary(s), do: h == s and path_match?(t,rest)
defp path_match?([_h|t],[s|rest]) when is_atom(s), do: path_match?(t,rest)
defp path_match?([],[]), do: true
defp path_match?(*, \_), do: false

defp extract*path_params(path, segs) do
Enum.zip(segs, path)
|> Enum.filter(fn {k,*}| is_atom(k) end)
|> Map.new(fn {k,v} -> {Atom.to_string(k),v} end)
end

# route_to_controller/3, add_version_features/3, send_not_supported_error/2

# remain exactly as they are.

end

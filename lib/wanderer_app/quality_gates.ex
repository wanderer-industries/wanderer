defmodule WandererApp.QualityGates do
  @moduledoc """
  Quality gates enforcement to prevent regressions in code quality metrics.

  This module defines thresholds for various quality metrics and provides
  functions to check if current metrics meet the required standards.
  """

  @doc """
  Returns the current quality thresholds.
  These represent the minimum acceptable values to prevent regression.
  """
  def current_thresholds do
    %{
      compilation: %{
        # Current state from CI output
        max_warnings: 148
      },
      credo: %{
        # Current state after our fixes
        max_issues: 87
      },
      dialyzer: %{
        # Current state
        max_errors: 0,
        # Current state
        max_warnings: 161
      },
      coverage: %{
        # Current minimum from CI
        minimum: 50.0
      },
      tests: %{
        max_failures: 0,
        max_duration_seconds: 300
      },
      documentation: %{
        # 40% of modules should have @moduledoc
        min_module_doc_coverage: 0.4
      }
    }
  end

  @doc """
  Returns the target quality goals we're working toward.
  These represent our ideal state.
  """
  def target_goals do
    %{
      compilation: %{
        max_warnings: 0
      },
      credo: %{
        max_issues: 10
      },
      dialyzer: %{
        max_errors: 0,
        max_warnings: 0
      },
      coverage: %{
        minimum: 85.0
      },
      tests: %{
        max_failures: 0,
        max_duration_seconds: 120
      },
      documentation: %{
        # 95% of modules should have @moduledoc
        min_module_doc_coverage: 0.95
      }
    }
  end

  @doc """
  Checks if a metric passes the current threshold (no regression).
  """
  def passes_threshold?(category, metric, value) when is_atom(category) and is_atom(metric) do
    threshold = get_in(current_thresholds(), [category, metric])

    case metric do
      # For "max" metrics, the value should be less than or equal to threshold
      metric
      when metric in [
             :max_warnings,
             :max_issues,
             :max_errors,
             :max_failures,
             :max_duration_seconds
           ] ->
        value <= threshold

      # For "min" metrics, the value should be greater than or equal to threshold
      metric when metric in [:minimum, :min_module_doc_coverage] ->
        value >= threshold

      _ ->
        raise ArgumentError, "Unknown metric: #{inspect(metric)}"
    end
  end

  @doc """
  Calculates progress toward the target goal for a metric.
  Returns a percentage (0-100) of how close we are to the goal.
  """
  def progress_toward_goal(category, metric, current_value) do
    current_threshold = get_in(current_thresholds(), [category, metric])
    target = get_in(target_goals(), [category, metric])

    case metric do
      # For "max" metrics, lower is better
      metric
      when metric in [
             :max_warnings,
             :max_issues,
             :max_errors,
             :max_failures,
             :max_duration_seconds
           ] ->
        if current_value <= target do
          100.0
        else
          progress = (current_threshold - current_value) / (current_threshold - target) * 100
          max(0.0, min(100.0, progress))
        end

      # For "min" metrics, higher is better
      metric when metric in [:minimum, :min_module_doc_coverage] ->
        if current_value >= target do
          100.0
        else
          progress = (current_value - current_threshold) / (target - current_threshold) * 100
          max(0.0, min(100.0, progress))
        end

      _ ->
        0.0
    end
  end

  @doc """
  Generates a quality report with current metrics and progress.
  """
  def quality_report do
    """
    # Quality Gates Report

    ## Current Thresholds (No Regression Allowed)

    ### Compilation
    - Max Warnings: #{current_thresholds().compilation.max_warnings}

    ### Credo
    - Max Issues: #{current_thresholds().credo.max_issues}

    ### Dialyzer
    - Max Errors: #{current_thresholds().dialyzer.max_errors}
    - Max Warnings: #{current_thresholds().dialyzer.max_warnings}

    ### Test Coverage
    - Minimum: #{current_thresholds().coverage.minimum}%

    ### Tests
    - Max Failures: #{current_thresholds().tests.max_failures}
    - Max Duration: #{current_thresholds().tests.max_duration_seconds}s

    ### Documentation
    - Min Module Doc Coverage: #{current_thresholds().documentation.min_module_doc_coverage * 100}%

    ## Target Goals

    ### Compilation
    - Max Warnings: #{target_goals().compilation.max_warnings} ✨

    ### Credo
    - Max Issues: #{target_goals().credo.max_issues} ✨

    ### Dialyzer
    - Max Errors: #{target_goals().dialyzer.max_errors} ✅
    - Max Warnings: #{target_goals().dialyzer.max_warnings} ✨

    ### Test Coverage
    - Minimum: #{target_goals().coverage.minimum}% ✨

    ### Documentation
    - Min Module Doc Coverage: #{target_goals().documentation.min_module_doc_coverage * 100}% ✨
    """
  end

  @doc """
  Updates thresholds based on improved metrics.
  Only allows improvements, never regressions.
  """
  def update_threshold_if_improved(category, metric, new_value) do
    current = get_in(current_thresholds(), [category, metric])

    improved? =
      case metric do
        # For "max" metrics, lower is better
        metric
        when metric in [
               :max_warnings,
               :max_issues,
               :max_errors,
               :max_failures,
               :max_duration_seconds
             ] ->
          new_value < current

        # For "min" metrics, higher is better
        metric when metric in [:minimum, :min_module_doc_coverage] ->
          new_value > current

        _ ->
          false
      end

    if improved? do
      {:ok, new_value, "Threshold improved from #{current} to #{new_value}"}
    else
      {:no_change, current,
       "Current threshold #{current} is better than or equal to #{new_value}"}
    end
  end
end

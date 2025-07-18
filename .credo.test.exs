# Credo configuration specific to test files
# This enforces stricter quality standards for test code

%{
  configs: [
    %{
      name: "test",
      files: %{
        included: ["test/"],
        excluded: ["test/support/"]
      },
      requires: [],
      strict: true,
      color: true,
      checks: [
        # Consistency checks
        {Credo.Check.Consistency.ExceptionNames, []},
        {Credo.Check.Consistency.LineEndings, []},
        {Credo.Check.Consistency.MultiAliasImportRequireUse, []},
        {Credo.Check.Consistency.ParameterPatternMatching, []},
        {Credo.Check.Consistency.SpaceAroundOperators, []},
        {Credo.Check.Consistency.SpaceInParentheses, []},
        {Credo.Check.Consistency.TabsOrSpaces, []},

        # Design checks - stricter for tests
        {Credo.Check.Design.AliasUsage, priority: :high},
        # Lower threshold for tests
        {Credo.Check.Design.DuplicatedCode, mass_threshold: 25},
        {Credo.Check.Design.TagTODO, []},
        {Credo.Check.Design.TagFIXME, []},

        # Readability checks - very important for tests
        {Credo.Check.Readability.AliasOrder, []},
        {Credo.Check.Readability.FunctionNames, []},
        {Credo.Check.Readability.LargeNumbers, []},
        # Slightly longer for test descriptions
        {Credo.Check.Readability.MaxLineLength, max_length: 120},
        {Credo.Check.Readability.ModuleAttributeNames, []},
        # Not required for test modules
        {Credo.Check.Readability.ModuleDoc, false},
        {Credo.Check.Readability.ModuleNames, []},
        {Credo.Check.Readability.ParenthesesInCondition, []},
        {Credo.Check.Readability.ParenthesesOnZeroArityDefs, []},
        {Credo.Check.Readability.PredicateFunctionNames, []},
        {Credo.Check.Readability.PreferImplicitTry, []},
        {Credo.Check.Readability.RedundantBlankLines, []},
        {Credo.Check.Readability.Semicolons, []},
        {Credo.Check.Readability.SpaceAfterCommas, []},
        {Credo.Check.Readability.StringSigils, []},
        {Credo.Check.Readability.TrailingBlankLine, []},
        {Credo.Check.Readability.TrailingWhiteSpace, []},
        {Credo.Check.Readability.UnnecessaryAliasExpansion, []},
        {Credo.Check.Readability.VariableNames, []},
        {Credo.Check.Readability.WithSingleClause, []},

        # Test-specific readability checks
        # Discourage single pipes in tests
        {Credo.Check.Readability.SinglePipe, []},
        # Specs not needed in tests
        {Credo.Check.Readability.Specs, false},
        {Credo.Check.Readability.StrictModuleLayout, []},

        # Refactoring opportunities - important for test maintainability
        # Higher limit for complex test setups
        {Credo.Check.Refactor.ABCSize, max_size: 50},
        {Credo.Check.Refactor.AppendSingleItem, []},
        {Credo.Check.Refactor.CondStatements, []},
        {Credo.Check.Refactor.CyclomaticComplexity, max_complexity: 10},
        # Lower for test helpers
        {Credo.Check.Refactor.FunctionArity, max_arity: 4},
        {Credo.Check.Refactor.LongQuoteBlocks, []},
        {Credo.Check.Refactor.MapInto, []},
        {Credo.Check.Refactor.MatchInCondition, []},
        {Credo.Check.Refactor.NegatedConditionsInUnless, []},
        {Credo.Check.Refactor.NegatedConditionsWithElse, []},
        # Keep tests flat
        {Credo.Check.Refactor.Nesting, max_nesting: 3},
        {Credo.Check.Refactor.UnlessWithElse, []},
        {Credo.Check.Refactor.WithClauses, []},
        {Credo.Check.Refactor.FilterFilter, []},
        {Credo.Check.Refactor.RejectReject, []},
        {Credo.Check.Refactor.RedundantWithClauseResult, []},

        # Warnings - all should be fixed
        {Credo.Check.Warning.ApplicationConfigInModuleAttribute, []},
        {Credo.Check.Warning.BoolOperationOnSameValues, []},
        {Credo.Check.Warning.ExpensiveEmptyEnumCheck, []},
        {Credo.Check.Warning.IExPry, []},
        {Credo.Check.Warning.IoInspect, []},
        {Credo.Check.Warning.OperationOnSameValues, []},
        {Credo.Check.Warning.OperationWithConstantResult, []},
        {Credo.Check.Warning.RaiseInsideRescue, []},
        {Credo.Check.Warning.UnusedEnumOperation, []},
        {Credo.Check.Warning.UnusedFileOperation, []},
        {Credo.Check.Warning.UnusedKeywordOperation, []},
        {Credo.Check.Warning.UnusedListOperation, []},
        {Credo.Check.Warning.UnusedPathOperation, []},
        {Credo.Check.Warning.UnusedRegexOperation, []},
        {Credo.Check.Warning.UnusedStringOperation, []},
        {Credo.Check.Warning.UnusedTupleOperation, []},
        {Credo.Check.Warning.UnsafeExec, []},

        # Test-specific checks
        # Important for test isolation
        {Credo.Check.Warning.LeakyEnvironment, []},

        # Custom checks for test patterns
        {
          Credo.Check.Refactor.PipeChainStart,
          # Factory functions
          excluded_functions: ["build", "create", "insert"],
          excluded_argument_types: [:atom, :number]
        }
      ],

      # Disable these checks for test files
      disabled: [
        # Tests don't need module docs
        {Credo.Check.Readability.ModuleDoc, []},
        # Tests don't need specs
        {Credo.Check.Readability.Specs, []},
        # Common in test setup
        {Credo.Check.Refactor.VariableRebinding, []}
      ]
    }
  ]
}

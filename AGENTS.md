# OpenAI Codex Instructions

## Build System & Development Commands

### Critical Build Rules

- **NEVER** use `cargo build`, `cargo test`, `cargo check`, `cargo fmt` and
  `cargo clippy` directly
- **ALWAYS** use `cargo make` targets when possible : `cargo make build` ,
  `cargo make format` , `cargo make check`, `cargo make test` ,
  `cargo make clippy`
- **IMMEDIATELY** run `cargo make check` and `cargo make format` after any code
  change to ensure it compiles
- **MANDATORY** validation sequence before any commit (see Validation Commands
  section)

## Architecture Guidelines & Technical Standards

### Incremental Development Methodology

- **Atomic Changes**: Make small, focused changes with single responsibility
- **Immediate Verification**: Run `cargo make check` after every modification
- **Compilation-First**: Ensure code compiles before adding new functionality
- **Test-Driven Validation**: Write tests before implementing complex logic

### Code Organization Standards

- **Function Complexity**: Maximum 50 lines per function with single, clear
  purpose
- **File Size Management**: Split files exceeding 300 lines using Rust's module
  system
- **Cognitive Load**: Limit nesting depth to 3 levels, prefer early returns
- **Dead Code Elimination**: Remove unused code immediately - use
  `cargo make clippy` to detect

## Rust-Specific Best Practices

### Naming Conventions & Style

- **Standard Compliance**: `snake_case` for functions/variables, `CamelCase`
  for types, `SCREAMING_SNAKE_CASE` for constants
- **Boolean Clarity**: Use descriptive prefixes (`is_`, `has_`, `should_`,
  `can_`) for boolean identifiers
- **Conversion Methods**: `to_` for borrowing conversions, `into_` for
  consuming conversions
- **Descriptive Naming**: Choose names that convey intent and domain meaning

### Idiomatic Rust Patterns

- **Type System Leverage**: Use Rust's type system to enforce correctness at
  compile time
- **Combinator Preference**: Favor `Option`/`Result` combinators (`map`,
  `and_then`, `filter`) over explicit matching
- **Iterator Chains**: Use iterator combinators instead of explicit loops for
  collection processing
- **Error Propagation**: Leverage `?` operator with proper error conversion
  traits
- **Zero Unwrap Policy**: Never use `unwrap()` or `expect()` in production code
  paths

### Memory Management & Performance

- **Reference Optimization**: Use `&str` over `String`, `&[T]` over `Vec<T>`
  for function parameters
- **Copy-on-Write**: Use `Cow<'a, T>` for data that's mostly read but
  occasionally modified
- **Standard Library First**: Prefer standard collections before specialized
  crates
- **Unsafe Minimization**: Avoid `unsafe` blocks, encapsulate when necessary
  with safe public APIs

## Error Handling Excellence

### Structured Error Management

- **Custom Error Types**: Use `thiserror` with `#[derive(Error)]` for
  domain-specific errors
- **Context Enrichment**: Add meaningful context using `.with_context()` for
  error chains
- **Library Error Strategy**: Use `thiserror` and `miette` instead of `anyhow`
  for structured errors
- **User-Centric Messages**: Convert technical errors to actionable user
  guidance
- **Comprehensive Testing**: Test error paths as thoroughly as success
  scenarios

## Static Linking & Deployment

### Build Configuration

- **Feature Flag Management**: Verify static linking support, enable
  appropriate features
- **Default Feature Control**: Use `default-features = false` when they
  conflict with static linking
- **Static Verification**: Test binaries with `ldd` to confirm static linking
  success

## Security & Input Validation

### Defense-in-Depth Approach

- **Zero Trust Input**: Treat all external inputs (CLI, files, network) as
  potentially malicious
- **Type-Driven Validation**: Use Rust's type system to enforce validation with
  newtype patterns
- **Range Validation**: Verify numeric inputs fall within acceptable bounds
- **Graceful Degradation**: Handle invalid inputs with descriptive errors,
  never panic
- **Data Privacy**: Never log sensitive information (passwords, tokens, PII) at
  any log level

## Documentation Standards

### Comprehensive Documentation Strategy

- **Public API Documentation**: Write detailed rustdoc comments (`///`) for all
  public items
- **Strategic Inline Comments**: Use `//` comments only for non-obvious
  decisions or complex algorithms
- **Module-Level Documentation**: Use `//!` to explain module purpose,
  organization, and usage patterns
- **Example-Driven Documentation**: Include code examples, error cases, and
  usage patterns in API docs

## Testing Strategy & Quality Assurance

### End-to-End Testing Priority

#### Comprehensive Testing Approach

- **E2E Focus**: Prioritize end-to-end tests over unit tests for user workflow
  validation
- **CLI Perspective**: Test complete user journeys from command-line interface
- **Scenario Coverage**: Test all subcommands across diverse real-world
  scenarios
- **Performance Validation**: Include performance tests with large directory
  structures
- **Cross-Platform Verification**: Ensure compatibility across different
  operating systems

### Test Organization & Quality Standards

#### Test Structure & Maintenance

- **Coverage Target**: Maintain minimum 80% test coverage for all non-UI code
- **AAA Pattern**: Follow Arrange-Act-Assert structure for clear, maintainable
  tests
- **Test Isolation**: Ensure tests are independent with no shared mutable state
- **Descriptive Naming**: Use test function names that clearly indicate
  scenario and expected outcome
- **Co-location Strategy**: Place unit tests in same file using `#[cfg(test)]`
  modules
- **Integration Separation**: Place integration tests in separate files within
  `tests/` directory

#### Test Execution & Lifecycle

- **Standard Execution**: Always use `cargo make test` for test execution
- **Environment Management**: Each test should setup, execute, verify, and
  cleanup independently
- **Maintenance Discipline**: Update tests immediately when related code
  changes
- **Regression Prevention**: Add specific tests for every fixed bug to prevent
  recurrence

## Validation Commands & Quality Gates

### Mandatory Validation Sequence

After making ANY changes, you MUST execute these validation commands in the
specified order:

```bash
# 1. Compilation verification
cargo make build

# 2. Test suite execution
cargo make test
```

## Development Workflow & Process

### Primary Development Cycle

#### Step-by-Step Development Process

1. **Atomic Changes**: Make small, focused code modifications with single
   responsibility
2. **Immediate Verification**: Run `cargo make check` after each change for
   fast feedback
3. **Compilation Verification**: Ensure code compiles successfully before
   proceeding
4. **Comprehensive Validation**: Execute full validation sequence (see
   Validation Commands)
5. **Documentation Updates**: Update relevant documentation for any public API
   changes
6. **Test Verification**: Confirm both unit and integration tests pass
   completely
7. **Atomic Commits**: Create focused commits with clear conventional commit
   messages

### Incremental Refactoring Process

#### Safe Refactoring Methodology

1. **Incremental Steps**: Break large refactorings into small, logical steps
2. **Continuous Testing**: Run test suite after each refactoring step
3. **Separation of Concerns**: Commit refactoring changes separately from
   feature additions
4. **Documentation of Intent**: Add comments explaining rationale for complex
   refactorings
5. **Verification at Each Step**: Thoroughly test after each incremental change

### Git Workflow Standards

#### Version Control Best Practices

- **Focused Branches**: Limit branches to single feature, bug fix, or
  improvement
- **Conventional Commits**: Use format `type(scope): description` (e.g.,
  `feat(parser): add JSON schema validation`)
- **Atomic Commits**: Ensure each commit represents a logical, self-contained
  unit of work
- **Meaningful Messages**: Write commit messages that explain the "why" not
  just the "what"

### Logging & Observability

#### Structured Logging Strategy

- **Tracing Framework**: Use `tracing` crate with appropriate verbosity levels
  (trace, debug, info, warn, error)
- **Context Enrichment**: Attach relevant key-value pairs to log messages for
  debugging
- **Privacy Protection**: Never log sensitive data (passwords, tokens, PII) at
  any verbosity level
- **Library Compatibility**: Use `log` facade to allow applications to choose
  logging implementation

### Performance & Cross-Platform Considerations

#### Performance Optimization

- **Benchmark Critical Paths**: Use `criterion` for stable, reliable
  performance benchmarking
- **Memory Profiling**: Profile memory usage to identify and eliminate
  inefficient patterns
- **Platform Testing**: Validate functionality across all supported platforms
  and architectures
- **Distribution Strategy**: Ensure self-contained binaries for simplified
  deployment

## Critical Development Rules & Constraints

### Mandatory Practices

- **Cargo Make Target Enforcement**: Always use `cargo make` targets when
  possible (`cargo make build`, `cargo make test`, etc.)
- **Immediate Compilation Checks**: Run `cargo make check` after every code
  change
- **Functional Programming Preference**: Prioritize iterator chains and
  combinators over imperative loops
- **Combinator-Driven Error Handling**: Use `Option`/`Result` combinators
  instead of manual conditional logic

### Quality Gates

- **Zero Compilation Warnings**: Address all compiler warnings before
  committing
- **Test Coverage Maintenance**: Maintain or improve test coverage with every
  change
- **Documentation Currency**: Keep documentation synchronized with code changes

### Performance Standards

- **Sub-second Response**: CLI commands should complete in under 1 second for
  typical use cases
- **Memory Efficiency**: Minimize memory allocations in hot paths
- **Binary Size**: Keep final binary size reasonable for distribution

This comprehensive guide ensures consistent, high-quality development practices
while maintaining the project's architectural integrity and performance
standards.

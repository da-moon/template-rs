# Rust Refactoring Guidelines

## Rules Table

| Rule ID | Rule Summary                                                     |
| ------- | ---------------------------------------------------------------- |
| R1      | Maximum 100 lines per file, split immediately when exceeded      |
| R2      | Maximum 20 lines per function, single responsibility             |
| R3      | All modules must be directories, never single files              |
| R4      | Each module directory has local errors.rs file                   |
| R5      | Use mod.rs for clean re-exports from submodules                  |
| R6      | One-to-one mapping between test files and source files           |
| R7      | Test file naming flattens directory structure with underscores   |
| R8      | Common functionality goes in common/ directory                   |
| R9      | Shared traits in common/traits.rs or common/traits/              |
| R10     | Constants in constants.rs or common/constants.rs                 |
| R11     | Use functional combinators over imperative control flow          |
| R12     | Prefer .map(), .filter(), .fold() over explicit loops            |
| R13     | Use .and_then(), .or_else() instead of if-let for Option/Result  |
| R14     | Use .transpose() for Option<Result<T, E>> → Result<Option<T>, E> |
| R15     | Use iterator chains for data transformation pipelines            |
| R16     | Use derive macros instead of manual implementations              |
| R17     | Prefer #[derive(Default)] over manual Default::default()         |
| R18     | Use serde macros for serialization instead of manual impl        |
| R19     | Use derive_builder for builder patterns                          |
| R20     | Use thiserror macros for error types                             |
| R21     | Design interfaces using traits for flexibility                   |
| R22     | Implement traits for structs rather than standalone functions    |
| R23     | Use trait objects for runtime polymorphism when needed           |
| R24     | Define generic functions with trait bounds                       |
| R25     | Prefer struct methods over functions taking struct pointers      |
| R26     | Use impl blocks to group related functionality                   |
| R27     | Use &self, &mut self, or self appropriately                      |
| R28     | Keep struct methods focused and atomic                           |
| R29     | Use enums instead of strings for classification/known types      |
| R30     | Use constants instead of static strings                          |
| R31     | Use single super:: only; prefer crate:: for multiple levels up   |
| R32     | Place shared traits in core modules                              |
| R33     | Place shared types and abstractions in core modules              |
| R34     | Define hierarchical error types with automatic conversion        |
| R35     | Use #[from] for error propagation from specific to general       |
| R36     | Place shared enums in core modules for consistent classification |
| R37     | Centralize shared constants in core modules                      |
| R38     | Apply systems thinking when designing core module content        |
| R39     | Co-locate trait implementations with trait or struct definition  |
| R40     | Split large trait implementations across multiple files          |

---

## R1: Maximum 100 lines per file, split immediately when exceeded

```rust
// ❌ BAD - Large file with multiple responsibilities
// src/parser.rs (150 lines)
pub struct JsonParser { ... }
impl JsonParser { ... }
pub struct XmlParser { ... }
impl XmlParser { ... }
pub struct YamlParser { ... }
impl YamlParser { ... }

// ✅ GOOD - Split into focused modules
// src/parser/mod.rs
pub mod json;
pub mod xml;
pub mod yaml;

// src/parser/json/mod.rs (< 100 lines)
pub struct JsonParser { ... }
impl JsonParser { ... }
```

## R2: Maximum 20 lines per function, single responsibility

```rust
// ❌ BAD - Large function with multiple responsibilities
pub fn process_document(content: String) -> Result<Document, Error> {
    if content.is_empty() {
        return Err(Error::EmptyContent);
    }
    let cleaned = content.trim().to_string();
    let lines: Vec<&str> = cleaned.lines().collect();
    let mut sections = Vec::new();
    for line in lines {
        if line.starts_with("##") {
            sections.push(Section::new(line));
        }
    }
    // ... 15 more lines
}

// ✅ GOOD - Atomic functions with single responsibility
pub fn process_document(content: String) -> Result<Document, Error> {
    let validated = validate_content(content)?;
    let cleaned = clean_content(validated)?;
    let sections = parse_sections(cleaned)?;
    build_document(sections)
}

fn validate_content(content: String) -> Result<String, Error> { ... }
fn clean_content(content: String) -> Result<String, Error> { ... }
fn parse_sections(content: String) -> Result<Vec<Section>, Error> { ... }
fn build_document(sections: Vec<Section>) -> Result<Document, Error> { ... }
```

## R3: All modules must be directories, never single files

```rust
// ❌ BAD - Single file modules
src/
├── parser.rs
├── validator.rs
└── serializer.rs

// ✅ GOOD - Directory-based modules (uniform pattern)
src/
├── parser/
│   ├── mod.rs
│   ├── errors.rs
│   └── json.rs
├── validator/
│   ├── mod.rs
│   ├── errors.rs
│   └── schema.rs
└── serializer/
    ├── mod.rs
    ├── errors.rs
    └── json.rs
```

## R4: Each module directory has local errors.rs file

```rust
// ✅ GOOD - Local error types
// src/parser/errors.rs
#[derive(Debug, Error, Diagnostic)]
pub enum ParserError {
    #[error("Invalid format: {format}")]
    #[diagnostic(code(parser::invalid_format))]
    InvalidFormat { format: String },

    #[error("Parse failed: {reason}")]
    #[diagnostic(code(parser::parse_failed))]
    ParseFailed { reason: String },
}

// src/parser/mod.rs
pub mod errors;
pub use errors::ParserError;
```

## R5: Use mod.rs for clean re-exports from submodules

```rust
// ✅ GOOD - Clean re-exports
// src/parser/mod.rs
mod json;
mod xml;
mod yaml;
pub mod errors;

pub use json::JsonParser;
pub use xml::XmlParser;
pub use yaml::YamlParser;
pub use errors::ParserError;

// Public API is clean
use crate::parser::{JsonParser, XmlParser, ParserError};
```

## R6: One-to-one mapping between test files and source files

```rust
// ✅ GOOD - One-to-one test mapping
src/parser/xml/
├── mod.rs
├── errors.rs
├── parser.rs
└── validator.rs

tests/parser/xml/
├── parser.rs      // Tests src/parser/xml/parser.rs
└── validator.rs   // Tests src/parser/xml/validator.rs
```

## R7: Test file naming flattens directory structure with underscores

Test files are placed flat in the `tests/` directory. The filename is derived
from the source path by:

- Replacing `/` with `_`
- Dropping `mod` from `mod.rs` files

```rust
// ✅ GOOD - Flat file structure with underscores
// For src/cmd/mod.rs
// Create tests/cmd.rs

// For src/cmd/errors.rs
// Create tests/cmd_errors.rs

// For src/sdk/python/definition/analyzer.rs
// Create tests/sdk_python_definition_analyzer.rs

// For src/parser/xml/parser.rs
// Create tests/parser_xml_parser.rs

// ❌ BAD - Nested directories in tests/
// tests/parser/xml/parser.rs
// tests/cmd/python/definition.rs
```

## R8: Common functionality goes in common/ directory

Module-specific shared functionality goes in local common/ directories.
System-wide shared functionality should follow R32-R38 and be placed in core
modules.

```rust
// ✅ GOOD - Module-level common directory
src/parser/
├── mod.rs
├── common/
│   ├── mod.rs
│   ├── traits.rs    // Parser-specific shared traits
│   ├── utils.rs     // Parser-specific utilities
│   └── helpers.rs   // Parser-specific helpers
├── json/
│   ├── mod.rs
│   ├── errors.rs
│   └── parser.rs
└── xml/
    ├── mod.rs
    ├── errors.rs
    └── parser.rs

// ✅ GOOD - System-wide shared in core (see R32-R38)
src/core/
├── traits.rs        // System-wide traits
├── types.rs         // System-wide types
├── enums.rs         // System-wide enums
└── constants.rs     // System-wide constants
```

## R9: Shared traits in common/traits.rs or common/traits/

Module-specific shared traits go in local common/traits.rs. System-wide traits
should follow R32 and be placed in core/traits.rs.

```rust
// ✅ GOOD - Module-specific shared traits
// src/parser/common/traits.rs
pub trait ParserHelper {
    fn preprocess(&self, input: &str) -> String;
    fn postprocess(&self, output: &str) -> String;
}

// ✅ GOOD - System-wide traits in core (see R32)
// src/core/traits.rs
pub trait Parser {
    type Output;
    type Error;

    fn parse(&self, input: String) -> Result<Self::Output, Self::Error>;
    fn validate(&self, input: &str) -> bool;
}

pub trait Analyzer {
    type Input;
    type Output;
    type Error;

    fn analyze(&self, input: Self::Input) -> Result<Self::Output, Self::Error>;
}

// src/parser/common/mod.rs
pub mod traits;
pub use traits::*;
```

## R10: Constants in constants.rs or common/constants.rs

Module-specific constants go in local constants.rs files. Shared constants
across modules should follow R37 and be placed in core modules.

```rust
// ✅ GOOD - Module-specific constants
// src/parser/constants.rs
pub const PARSER_BUFFER_SIZE: usize = 4096;
pub const MAX_PARSE_DEPTH: usize = 100;

// src/parser/xml/constants.rs
pub const XML_HEADER: &str = "<?xml version=\"1.0\"?>";
pub const XML_ENCODING: &str = "UTF-8";

// ✅ GOOD - Shared constants in core (see R37)
// src/core/constants.rs
pub const MAX_FILE_SIZE: usize = 10 * 1024 * 1024; // 10MB
pub const DEFAULT_TIMEOUT: u64 = 30;

// ❌ BAD - Inline magic strings
fn validate_xml(content: &str) -> bool {
    content.starts_with("<?xml version=\"1.0\"?>")
}

// ✅ GOOD - Use constants
fn validate_xml(content: &str) -> bool {
    content.starts_with(XML_HEADER)
}
```

## R11: Use functional combinators over imperative control flow

```rust
// ❌ BAD - Imperative style
let mut results = Vec::new();
for item in items {
    if let Some(processed) = process_item(item) {
        if processed.is_valid() {
            results.push(processed);
        }
    }
}

// ✅ GOOD - Functional combinators
let results: Vec<_> = items
    .into_iter()
    .filter_map(|item| process_item(item))
    .filter(|processed| processed.is_valid())
    .collect();
```

## R12: Prefer .map(), .filter(), .fold() over explicit loops

```rust
// ❌ BAD - Explicit loops
let mut sum = 0;
for item in items {
    sum += item.value;
}

let mut filtered = Vec::new();
for item in items {
    if item.is_active {
        filtered.push(item);
    }
}

// ✅ GOOD - Iterator combinators
let sum: i32 = items.iter().map(|item| item.value).sum();

let filtered: Vec<_> = items
    .into_iter()
    .filter(|item| item.is_active)
    .collect();

// ❌ BAD - Aggregating with a loop
let mut total = 0;
for item in numbers {
    total += item;
}

// ✅ GOOD - Use `fold`
let total = numbers.iter().fold(0, |acc, item| acc + item);
```

### Additional Patterns

```rust
// ❌ BAD - Searching for item in a loop
let mut found = None;
for item in items {
    if item.id == target {
        found = Some(item.clone());
        break;
    }
}

// ✅ GOOD - Use `find`
let found = items.iter().find(|item| item.id == target).cloned();
```

```rust
// ❌ BAD - Checking condition with loop
let mut has_active = false;
for item in items {
    if item.active {
        has_active = true;
        break;
    }
}

// ✅ GOOD - Use `any`
let has_active = items.iter().any(|item| item.active);
```

```rust
// ❌ BAD - Iterating children manually
for child in node.children() {
    process(child);
}

// ✅ GOOD - Use `for_each`
node.children().for_each(process);
```

## R13: Use .and_then(), .or_else() instead of if-let for Option/Result

```rust
// ❌ BAD - if-let pattern
let result = if let Some(config) = config_option {
    if let Ok(loaded) = load_config(config) {
        Ok(loaded)
    } else {
        Err(Error::LoadFailed)
    }
} else {
    Ok(Default::default())
};

// ✅ GOOD - Functional combinators
let result = config_option
    .map(|config| load_config(config))
    .transpose()
    .map_err(|_| Error::LoadFailed)?
    .unwrap_or_default();
```

## R14: Use .transpose() for Option<Result<T, E>> → Result<Option<T>, E>

```rust
// ❌ BAD - Manual handling
let result = match config_file {
    Some(path) => match load_config(path) {
        Ok(config) => Ok(Some(config)),
        Err(e) => Err(e),
    },
    None => Ok(None),
};

// ✅ GOOD - Use transpose
let result: Result<Option<Config>, Error> = config_file
    .map(|path| load_config(path))
    .transpose();
```

## R15: Use iterator chains for data transformation pipelines

```rust
// ❌ BAD - Multiple intermediate collections
let mut step1 = Vec::new();
for item in input {
    if item.is_valid() {
        step1.push(item);
    }
}

let mut step2 = Vec::new();
for item in step1 {
    step2.push(transform(item));
}

let mut final_result = Vec::new();
for item in step2 {
    if let Ok(processed) = process(item) {
        final_result.push(processed);
    }
}

// ✅ GOOD - Single iterator chain
let final_result: Vec<_> = input
    .into_iter()
    .filter(|item| item.is_valid())
    .map(|item| transform(item))
    .filter_map(|item| process(item).ok())
    .collect();
```

## R16: Use derive macros instead of manual implementations

```rust
// ❌ BAD - Manual implementations
impl Debug for Config {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("Config")
            .field("name", &self.name)
            .field("enabled", &self.enabled)
            .finish()
    }
}

impl Clone for Config {
    fn clone(&self) -> Self {
        Self {
            name: self.name.clone(),
            enabled: self.enabled,
        }
    }
}

// ✅ GOOD - Derive macros
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Config {
    pub name: String,
    pub enabled: bool,
}
```

## R17: Prefer #[derive(Default)] over manual Default::default()

```rust
// ❌ BAD - Manual Default implementation
impl Default for Config {
    fn default() -> Self {
        Self {
            name: String::new(),
            enabled: false,
            timeout: 30,
        }
    }
}

// ✅ GOOD - Derive Default with custom defaults
#[derive(Default)]
pub struct Config {
    #[default]
    pub name: String,
    pub enabled: bool,
    #[default = "30"]
    pub timeout: u64,
}
```

## R18: Use serde macros for serialization instead of manual impl

```rust
// ❌ BAD - Manual serialization
impl Serialize for Config {
    fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: Serializer,
    {
        let mut state = serializer.serialize_struct("Config", 2)?;
        state.serialize_field("name", &self.name)?;
        state.serialize_field("enabled", &self.enabled)?;
        state.end()
    }
}

// ✅ GOOD - Serde derive macros
#[derive(Serialize, Deserialize)]
pub struct Config {
    pub name: String,
    pub enabled: bool,
    #[serde(default = "default_timeout")]
    pub timeout: u64,
}

fn default_timeout() -> u64 { 30 }
```

## R19: Use derive_builder for builder patterns

```rust
// ❌ BAD - Manual builder implementation
pub struct SearchRequestBuilder {
    query: Option<String>,
    limit: Option<usize>,
    offset: Option<usize>,
}

impl SearchRequestBuilder {
    pub fn new() -> Self { ... }
    pub fn query(mut self, query: String) -> Self { ... }
    pub fn limit(mut self, limit: usize) -> Self { ... }
    pub fn build(self) -> Result<SearchRequest, BuildError> { ... }
}

// ✅ GOOD - derive_builder macro
#[derive(Builder)]
#[builder(setter(into))]
pub struct SearchRequest {
    pub query: String,
    #[builder(default = "10")]
    pub limit: usize,
    #[builder(default = "0")]
    pub offset: usize,
}
```

## R20: Use thiserror macros for error types

```rust
// ❌ BAD - Manual error implementation
#[derive(Debug)]
pub enum ParserError {
    InvalidFormat(String),
    IoError(std::io::Error),
}

impl std::fmt::Display for ParserError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::InvalidFormat(msg) => write!(f, "Invalid format: {}", msg),
            Self::IoError(err) => write!(f, "IO error: {}", err),
        }
    }
}

impl std::error::Error for ParserError {
    fn source(&self) -> Option<&(dyn std::error::Error + 'static)> {
        match self {
            Self::IoError(err) => Some(err),
            _ => None,
        }
    }
}

// ✅ GOOD - thiserror macros
#[derive(Debug, Error, Diagnostic)]
pub enum ParserError {
    #[error("Invalid format: {format}")]
    #[diagnostic(code(parser::invalid_format))]
    InvalidFormat { format: String },

    #[error("IO error occurred")]
    #[diagnostic(code(parser::io_error))]
    IoError(#[from] std::io::Error),
}
```

## R21: Design interfaces using traits for flexibility

```rust
// ❌ BAD - Concrete type dependencies
pub struct DocumentProcessor {
    json_parser: JsonParser,
    xml_parser: XmlParser,
}

impl DocumentProcessor {
    pub fn process_json(&self, input: String) -> Result<Document, Error> {
        self.json_parser.parse(input)
    }

    pub fn process_xml(&self, input: String) -> Result<Document, Error> {
        self.xml_parser.parse(input)
    }
}

// ✅ GOOD - Trait-based design
pub trait Parser {
    type Output;
    type Error;

    fn parse(&self, input: String) -> Result<Self::Output, Self::Error>;
}

pub struct DocumentProcessor<P: Parser> {
    parser: P,
}

impl<P: Parser> DocumentProcessor<P> {
    pub fn new(parser: P) -> Self {
        Self { parser }
    }

    pub fn process(&self, input: String) -> Result<P::Output, P::Error> {
        self.parser.parse(input)
    }
}
```

## R22: Implement traits for structs rather than standalone functions

```rust
// ❌ BAD - Standalone functions
pub fn parse_json(parser: &JsonParser, input: String) -> Result<Document, JsonError> {
    // parsing logic
}

pub fn validate_json(parser: &JsonParser, input: &str) -> bool {
    // validation logic
}

// ✅ GOOD - Trait implementation for struct
impl Parser for JsonParser {
    type Output = Document;
    type Error = JsonError;

    fn parse(&self, input: String) -> Result<Self::Output, Self::Error> {
        // parsing logic
    }
}

impl Validator for JsonParser {
    fn validate(&self, input: &str) -> bool {
        // validation logic
    }
}
```

## R23: Use trait objects for runtime polymorphism when needed

```rust
// ✅ GOOD - Trait objects for runtime polymorphism
pub struct DocumentProcessor {
    parsers: Vec<Box<dyn Parser<Output = Document, Error = ParseError>>>,
}

impl DocumentProcessor {
    pub fn add_parser(&mut self, parser: Box<dyn Parser<Output = Document, Error = ParseError>>) {
        self.parsers.push(parser);
    }

    pub fn process_with_all(&self, input: String) -> Vec<Result<Document, ParseError>> {
        self.parsers
            .iter()
            .map(|parser| parser.parse(input.clone()))
            .collect()
    }
}
```

## R24: Define generic functions with trait bounds

```rust
// ❌ BAD - Specific type parameters
pub fn process_json_document(parser: JsonParser, input: String) -> Result<Document, JsonError> {
    parser.parse(input)
}

pub fn process_xml_document(parser: XmlParser, input: String) -> Result<Document, XmlError> {
    parser.parse(input)
}

// ✅ GOOD - Generic with trait bounds
pub fn process_document<P>(parser: P, input: String) -> Result<P::Output, P::Error>
where
    P: Parser,
{
    parser.parse(input)
}

pub fn process_and_validate<P>(parser: P, input: String) -> Result<P::Output, P::Error>
where
    P: Parser + Validator,
{
    if parser.validate(&input) {
        parser.parse(input)
    } else {
        Err(P::Error::validation_failed())
    }
}
```

## R25: Prefer struct methods over functions taking struct pointers

```rust
// ❌ BAD - Functions taking struct pointers
pub fn parse_document(parser: &JsonParser, input: String) -> Result<Document, JsonError> {
    // parsing logic
}

pub fn validate_input(parser: &JsonParser, input: &str) -> bool {
    // validation logic
}

pub fn configure_parser(parser: &mut JsonParser, config: Config) {
    // configuration logic
}

// ✅ GOOD - Struct methods
impl JsonParser {
    pub fn parse(&self, input: String) -> Result<Document, JsonError> {
        // parsing logic
    }

    pub fn validate(&self, input: &str) -> bool {
        // validation logic
    }

    pub fn configure(&mut self, config: Config) {
        // configuration logic
    }
}
```

## R26: Use impl blocks to group related functionality

```rust
// ❌ BAD - Scattered implementations
impl JsonParser {
    pub fn parse(&self, input: String) -> Result<Document, JsonError> { ... }
}

impl JsonParser {
    pub fn new() -> Self { ... }
}

impl JsonParser {
    pub fn validate(&self, input: &str) -> bool { ... }
}

// ✅ GOOD - Grouped functionality
impl JsonParser {
    // Construction
    pub fn new() -> Self { ... }

    pub fn with_config(config: Config) -> Self { ... }

    // Core operations
    pub fn parse(&self, input: String) -> Result<Document, JsonError> { ... }

    pub fn validate(&self, input: &str) -> bool { ... }

    // Configuration
    pub fn set_config(&mut self, config: Config) { ... }
}
```

## R27: Use &self, &mut self, or self appropriately

```rust
// ✅ GOOD - Appropriate self usage
impl JsonParser {
    // Immutable access - use &self
    pub fn parse(&self, input: String) -> Result<Document, JsonError> { ... }

    pub fn validate(&self, input: &str) -> bool { ... }

    // Mutable access - use &mut self
    pub fn configure(&mut self, config: Config) { ... }

    pub fn reset(&mut self) { ... }

    // Consuming - use self
    pub fn into_config(self) -> Config { ... }

    pub fn finalize(self) -> Result<ProcessedParser, JsonError> { ... }
}
```

## R28: Keep struct methods focused and atomic

```rust
// ❌ BAD - Large method with multiple responsibilities
impl DocumentProcessor {
    pub fn process_document(&mut self, input: String) -> Result<Document, ProcessError> {
        // Validation (5 lines)
        if input.is_empty() { return Err(ProcessError::EmptyInput); }
        let trimmed = input.trim();

        // Parsing (10 lines)
        let parsed = match self.format {
            Format::Json => self.parse_json(trimmed)?,
            Format::Xml => self.parse_xml(trimmed)?,
        };

        // Transformation (8 lines)
        let transformed = self.transform_document(parsed)?;

        // Validation (5 lines)
        self.validate_result(&transformed)?;

        Ok(transformed)
    }
}

// ✅ GOOD - Atomic methods
impl DocumentProcessor {
    pub fn process_document(&mut self, input: String) -> Result<Document, ProcessError> {
        let validated = self.validate_input(input)?;
        let parsed = self.parse_document(validated)?;
        let transformed = self.transform_document(parsed)?;
        self.validate_result(&transformed)?;
        Ok(transformed)
    }

    fn validate_input(&self, input: String) -> Result<String, ProcessError> { ... }

    fn parse_document(&self, input: String) -> Result<RawDocument, ProcessError> { ... }

    fn transform_document(&self, raw: RawDocument) -> Result<Document, ProcessError> { ... }

    fn validate_result(&self, doc: &Document) -> Result<(), ProcessError> { ... }
}
```

## R29: Use enums instead of strings for classification/known types

```rust
// ❌ BAD - String-based classification
pub struct DocumentProcessor {
    pub format: String,  // "json", "xml", "yaml"
    pub mode: String,    // "strict", "lenient"
}

pub fn process_document(format: &str, input: String) -> Result<Document, Error> {
    match format {
        "json" => parse_json(input),
        "xml" => parse_xml(input),
        "yaml" => parse_yaml(input),
        _ => Err(Error::UnsupportedFormat),
    }
}

// ✅ GOOD - Enum-based classification
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum DocumentFormat {
    Json,
    Xml,
    Yaml,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ProcessingMode {
    Strict,
    Lenient,
}

pub struct DocumentProcessor {
    pub format: DocumentFormat,
    pub mode: ProcessingMode,
}

pub fn process_document(format: DocumentFormat, input: String) -> Result<Document, Error> {
    match format {
        DocumentFormat::Json => parse_json(input),
        DocumentFormat::Xml => parse_xml(input),
        DocumentFormat::Yaml => parse_yaml(input),
    }
}
```

## R30: Use constants instead of static strings

```rust
// ❌ BAD - Magic strings scattered throughout code
pub fn validate_xml(content: &str) -> bool {
    content.starts_with("<?xml version=\"1.0\"?>") &&
    content.contains("</root>")
}

pub fn create_xml_template() -> String {
    format!("{}\n<root></root>", "<?xml version=\"1.0\"?>")
}

// ✅ GOOD - Centralized constants
pub const XML_DECLARATION: &str = "<?xml version=\"1.0\"?>";
pub const XML_ROOT_OPEN: &str = "<root>";
pub const XML_ROOT_CLOSE: &str = "</root>";
pub const DEFAULT_ENCODING: &str = "UTF-8";
pub const MAX_DEPTH: usize = 100;

pub fn validate_xml(content: &str) -> bool {
    content.starts_with(XML_DECLARATION) &&
    content.contains(XML_ROOT_CLOSE)
}

pub fn create_xml_template() -> String {
    format!("{}\n{}{}", XML_DECLARATION, XML_ROOT_OPEN, XML_ROOT_CLOSE)
}
```

## R31: Use relative imports when implementing traits close to definition

Use `super::` for immediate parent modules only. For anything beyond one level
up, use absolute `crate::` imports.

```rust
// ❌ BAD - Using absolute path when implementation is close to trait definition
// src/sdk/python/definition/analyzer.rs
impl crate::sdk::python::definition::traits::DefinitionAnalyzerTrait for DefinitionAnalyzer {
    fn find_definition(&mut self, uri: &Uri, position: Position) -> anyhow::Result<Vec<Location>> {
        DefinitionAnalyzer::find_definition(self, uri, position)
    }
}

// ❌ BAD - Multiple super levels
// src/parser/json/parser.rs
use super::super::traits::Parser;  // Don't use multiple super::
use super::super::super::common::types;  // Definitely don't do this

// ✅ GOOD - One super for immediate parent
// src/sdk/python/definition/analyzer.rs
use super::traits::DefinitionAnalyzerTrait;

impl DefinitionAnalyzerTrait for DefinitionAnalyzer {
    fn find_definition(&mut self, uri: &Uri, position: Position) -> anyhow::Result<Vec<Location>> {
        DefinitionAnalyzer::find_definition(self, uri, position)
    }
}

// ✅ GOOD - Use crate:: for multiple levels up
// src/parser/json/parser.rs
use crate::parser::traits::Parser;  // More than one level? Use crate::
use crate::common::types;  // Clear and unambiguous

impl Parser for JsonParser {
    // Implementation
}
```

### Guidelines for import paths:

1. **One level up**: Use `super::` (immediate parent only)
2. **Multiple levels up**: Use `crate::` for clarity
3. **Sibling modules**: Use `super::` then the sibling name
4. **Core modules**: Always use `crate::core::`

```rust
// Examples of correct import patterns
// src/storage/filesystem/impl_storage/read.rs

use super::FileSystem;  // ✅ One level up to parent (impl_storage -> filesystem)
use crate::storage::filesystem::FileSystem;  // ❌ Don't use crate:: for one level

use super::super::Cache;  // ❌ BAD - multiple super
use crate::storage::filesystem::Cache;  // ✅ GOOD - use crate:: instead

use crate::core::errors::StorageError;  // ✅ Always use crate:: for core
```

## R32: Place shared traits in core modules

Traits that define common interfaces used by multiple implementations should be
placed in core modules to avoid cross-dependencies between feature modules.

```rust
// ❌ BAD - Generic trait in specific feature module
// src/features/json_parser/traits.rs
pub trait Parser {
    type Output;
    type Error;
    fn parse(&self, input: String) -> Result<Self::Output, Self::Error>;
}

// src/features/xml_parser/parser.rs
use crate::features::json_parser::traits::Parser; // Cross-feature dependency!

// ✅ GOOD - Shared trait in core module
// src/core/traits.rs or src/core/parser/traits.rs
pub trait Parser {
    type Output;
    type Error;
    fn parse(&self, input: String) -> Result<Self::Output, Self::Error>;
}

// src/features/json_parser/parser.rs
use crate::core::traits::Parser;

impl Parser for JsonParser {
    // JSON-specific implementation
}

// src/features/xml_parser/parser.rs
use crate::core::traits::Parser;

impl Parser for XmlParser {
    // XML-specific implementation
}
```

### Examples of traits that belong in core:

```rust
// src/core/traits.rs - Shared behavior contracts
pub trait Validator {
    fn validate(&self, input: &str) -> bool;
}

pub trait Processor {
    type Input;
    type Output;
    type Error;

    fn process(&self, input: Self::Input) -> Result<Self::Output, Self::Error>;
}

pub trait Repository<T> {
    type Error;

    fn find(&self, id: &str) -> Result<Option<T>, Self::Error>;
    fn save(&mut self, entity: T) -> Result<(), Self::Error>;
}
```

## R33: Place shared types and abstractions in core modules

Common data structures, enums, and type definitions used across multiple
modules should be centralized in core to prevent duplication and ensure
consistency.

```rust
// ❌ BAD - Duplicated types across modules
// src/features/api/types.rs
pub struct Config {
    pub timeout: Duration,
    pub retry_count: u32,
}

// src/features/storage/types.rs
pub struct Config { // Duplication!
    pub timeout: Duration,
    pub retry_count: u32,
}

// ✅ GOOD - Shared types in core
// src/core/types.rs
pub struct Config {
    pub timeout: Duration,
    pub retry_count: u32,
}

pub enum ProcessingMode {
    Strict,
    Lenient,
}

pub type Result<T> = std::result::Result<T, crate::core::errors::CoreError>;

// src/features/api/handler.rs
use crate::core::types::{Config, ProcessingMode};

// src/features/storage/service.rs
use crate::core::types::{Config, ProcessingMode};
```

## R34: Define hierarchical error types with automatic conversion

Create a hierarchy of error types from general (core) to specific
(feature/module), with automatic conversion using thiserror's `#[from]`
attribute while maintaining miette diagnostics.

```rust
// ✅ GOOD - Core error type (most general)
// src/core/errors.rs
#[derive(Debug, Error, Diagnostic)]
pub enum CoreError {
    #[error("Validation failed: {message}")]
    #[diagnostic(code(core::validation))]
    ValidationError { message: String },

    #[error("Processing failed: {reason}")]
    #[diagnostic(code(core::processing))]
    ProcessingError { reason: String },

    #[error("IO operation failed")]
    #[diagnostic(code(core::io))]
    IoError(#[from] std::io::Error),
}

// ✅ GOOD - Feature-level error (more specific)
// src/sdk/python/errors.rs
#[derive(Debug, Error, Diagnostic)]
pub enum PythonError {
    #[error("Python syntax error: {details}")]
    #[diagnostic(code(python::syntax))]
    SyntaxError { details: String },

    #[error("Import resolution failed: {module}")]
    #[diagnostic(code(python::import))]
    ImportError { module: String },

    // Automatic conversion from CoreError
    #[error(transparent)]
    #[diagnostic(transparent)]
    Core(#[from] crate::core::errors::CoreError),
}

// ✅ GOOD - Module-level error (most specific)
// src/sdk/python/definition/errors.rs
#[derive(Debug, Error, Diagnostic)]
pub enum DefinitionError {
    #[error("Symbol not found: {symbol}")]
    #[diagnostic(code(python::definition::not_found))]
    SymbolNotFound { symbol: String },

    #[error("Multiple definitions found for: {symbol}")]
    #[diagnostic(code(python::definition::ambiguous))]
    AmbiguousDefinition { symbol: String },

    // Automatic conversion from PythonError
    #[error(transparent)]
    #[diagnostic(transparent)]
    Python(#[from] super::super::errors::PythonError),
}
```

## R35: Use #[from] for error propagation from specific to general

Leverage thiserror's `#[from]` attribute to enable automatic error conversion
up the hierarchy, allowing specific errors to be seamlessly converted to more
general ones.

```rust
// ✅ GOOD - Automatic error propagation
// src/sdk/python/definition/analyzer.rs
use super::errors::DefinitionError;
use crate::sdk::python::errors::PythonError;
use crate::core::errors::CoreError;

impl DefinitionAnalyzer {
    pub fn analyze(&self) -> Result<Definition, DefinitionError> {
        // CoreError automatically converts to PythonError, then to DefinitionError
        let file_content = std::fs::read_to_string(&self.path)?; // io::Error -> CoreError -> PythonError -> DefinitionError

        // Direct DefinitionError
        let symbol = self.find_symbol()
            .ok_or_else(|| DefinitionError::SymbolNotFound {
                symbol: self.symbol.clone()
            })?;

        Ok(symbol)
    }
}

// Usage at different levels
// src/sdk/python/service.rs
impl PythonService {
    pub fn process(&self) -> Result<Output, PythonError> {
        // DefinitionError automatically converts to PythonError
        let definition = self.analyzer.analyze()?;
        Ok(self.transform(definition))
    }
}

// src/api/handler.rs
impl ApiHandler {
    pub fn handle(&self) -> Result<Response, CoreError> {
        // PythonError automatically converts to CoreError
        let result = self.python_service.process()?;
        Ok(Response::from(result))
    }
}
```

### Error Hierarchy Guidelines:

1. **Core errors** are the most general, representing cross-cutting concerns
2. **Feature/Language errors** are more specific to a domain or implementation
3. **Module errors** are the most specific, representing particular
   functionality
4. Always use `#[error(transparent)]` and `#[diagnostic(transparent)]` for
   wrapped errors
5. Each level should only know about the level directly above it

### Example Directory Structure with Error Hierarchy:

```
src/
├── core/
│   ├── mod.rs
│   ├── errors.rs           # CoreError - most general errors
│   ├── traits.rs           # Shared trait definitions
│   └── types.rs            # Common types
├── sdk/
│   ├── mod.rs
│   ├── errors.rs           # SdkError with #[from] CoreError
│   ├── python/
│   │   ├── mod.rs
│   │   ├── errors.rs       # PythonError with #[from] SdkError
│   │   ├── definition/
│   │   │   ├── mod.rs
│   │   │   ├── errors.rs   # DefinitionError with #[from] PythonError
│   │   │   └── analyzer.rs
│   │   └── completion/
│   │       ├── mod.rs
│   │       ├── errors.rs   # CompletionError with #[from] PythonError
│   │       └── provider.rs
│   └── rust/
│       ├── mod.rs
│       ├── errors.rs       # RustError with #[from] SdkError
│       └── analyzer/
│           ├── mod.rs
│           ├── errors.rs   # AnalyzerError with #[from] RustError
│           └── service.rs
└── api/
    ├── mod.rs
    ├── errors.rs           # ApiError with #[from] CoreError
    └── handlers.rs
```

## R36: Place shared enums in core modules for consistent classification

Enums used for classification across multiple modules should be centralized in
core to ensure consistent semantics and prevent duplicate definitions.

```rust
// ❌ BAD - Duplicate enum definitions across modules
// src/features/parser/types.rs
pub enum NodeKind {
    Function,
    Class,
    Variable,
}

// src/features/analyzer/types.rs
pub enum NodeType {  // Same concept, different name!
    Function,
    Class,
    Variable,
    Method,  // Inconsistent variants
}

// ✅ GOOD - Centralized enum in core
// src/core/enums.rs
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum NodeKind {
    Function,
    Class,
    Method,
    Variable,
    Module,
    Import,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Visibility {
    Public,
    Private,
    Protected,
    Internal,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum OperationMode {
    Strict,      // Fail on any error
    Lenient,     // Continue on recoverable errors
    BestEffort,  // Complete as much as possible
}

// src/features/parser/analyzer.rs
use crate::core::enums::{NodeKind, Visibility};

// src/features/analyzer/service.rs
use crate::core::enums::{NodeKind, OperationMode};
```

### Guidelines for shared enums:

1. **Semantic Unity**: If multiple modules classify the same concept, use one
   enum
2. **Extensibility**: Design enums to accommodate future variants
3. **Derive Common Traits**: Always derive Debug, Clone, PartialEq, Eq
4. **Consider Copy**: For simple enums without data, derive Copy
5. **Document Variants**: Each variant should have clear documentation

```rust
// ✅ GOOD - Well-designed shared enum
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum SymbolKind {
    /// A file or module
    File,
    /// A module namespace
    Module,
    /// A namespace
    Namespace,
    /// A package
    Package,
    /// A class
    Class,
    /// A method of a class
    Method,
    /// A property of a class
    Property,
    /// A field of a class
    Field,
    /// A constructor
    Constructor,
    /// An enum
    Enum,
    /// An interface
    Interface,
    /// A function
    Function,
    /// A variable
    Variable,
    /// A constant
    Constant,
    /// A string
    String,
    /// A number
    Number,
    /// A boolean
    Boolean,
    /// An array
    Array,
}
```

## R37: Centralize shared constants in core modules

Constants used across multiple modules should be defined in core to maintain
consistency and enable easy configuration changes.

```rust
// ❌ BAD - Duplicate constants across modules
// src/features/parser/constants.rs
pub const MAX_FILE_SIZE: usize = 10 * 1024 * 1024; // 10MB
pub const DEFAULT_TIMEOUT: u64 = 30;

// src/features/analyzer/config.rs
pub const MAX_FILE_SIZE: usize = 10_485_760; // Same value, different representation!
pub const TIMEOUT_SECONDS: u64 = 30; // Same concept, different name

// ✅ GOOD - Centralized constants in core
// src/core/constants.rs
/// Maximum file size for processing (10MB)
pub const MAX_FILE_SIZE: usize = 10 * 1024 * 1024;

/// Default operation timeout in seconds
pub const DEFAULT_TIMEOUT_SECS: u64 = 30;

/// Maximum recursion depth for analysis
pub const MAX_RECURSION_DEPTH: usize = 100;

/// Default buffer size for I/O operations
pub const DEFAULT_BUFFER_SIZE: usize = 8192;

// Version constants
pub const VERSION_MAJOR: u32 = 1;
pub const VERSION_MINOR: u32 = 0;
pub const VERSION_PATCH: u32 = 0;

// Protocol constants
pub const PROTOCOL_VERSION: &str = "2.0";
pub const ENCODING: &str = "utf-8";

// src/features/parser/service.rs
use crate::core::constants::{MAX_FILE_SIZE, DEFAULT_BUFFER_SIZE};

// src/features/analyzer/config.rs
use crate::core::constants::{MAX_FILE_SIZE, DEFAULT_TIMEOUT_SECS};
```

### Guidelines for shared constants:

1. **Clear Naming**: Use descriptive names with units (e.g., `_SECS`, `_MB`)
2. **Documentation**: Always document the purpose and units
3. **Type Safety**: Use appropriate types (usize for sizes, Duration for time)
4. **Grouping**: Group related constants together
5. **Compile-Time Values**: Prefer const over static for compile-time constants

```rust
// ✅ GOOD - Well-organized constants module
// src/core/constants.rs

// Size limits
pub mod limits {
    /// Maximum file size in bytes (10MB)
    pub const MAX_FILE_SIZE: usize = 10 * 1024 * 1024;

    /// Maximum line length for processing
    pub const MAX_LINE_LENGTH: usize = 1000;

    /// Maximum function length in lines
    pub const MAX_FUNCTION_LINES: usize = 20;
}

// Timeouts
pub mod timeouts {
    use std::time::Duration;

    /// Default operation timeout
    pub const DEFAULT: Duration = Duration::from_secs(30);

    /// Fast operation timeout
    pub const FAST: Duration = Duration::from_secs(5);

    /// Long operation timeout
    pub const LONG: Duration = Duration::from_secs(300);
}

// Protocol
pub mod protocol {
    /// LSP protocol version
    pub const VERSION: &str = "3.17.0";

    /// Default encoding
    pub const ENCODING: &str = "utf-8";

    /// Maximum message size
    pub const MAX_MESSAGE_SIZE: usize = 16 * 1024 * 1024;
}
```

## R38: Apply systems thinking when designing core module content

Use systems thinking to anticipate future needs and design core modules that
will scale with your project's growth. Consider the entire system's evolution,
not just current requirements.

### Systems Thinking Questions for Core Module Design:

1. **Future Integration**: What external systems might we integrate with?
2. **Cross-Cutting Concerns**: What aspects affect multiple parts of the
   system?
3. **Evolution Patterns**: How might our domain model evolve?
4. **Standardization**: What concepts benefit from system-wide consistency?
5. **Configuration**: What values might need centralized configuration?

```rust
// ✅ GOOD - Systems thinking applied to core design
// src/core/mod.rs

// Anticipated future needs documented
pub mod traits;      // Interfaces that enable extension
pub mod types;       // Domain-agnostic types
pub mod enums;       // Standardized classifications
pub mod constants;   // System-wide configuration values
pub mod errors;      // Base error hierarchy
pub mod metrics;     // Performance & monitoring (future need)
pub mod events;      // Event system (anticipated need)
pub mod plugins;     // Plugin interface (extensibility)

// src/core/events.rs - Designed for future event-driven features
#[derive(Debug, Clone)]
pub enum SystemEvent {
    Started { timestamp: Instant },
    Stopped { timestamp: Instant, reason: StopReason },
    Error { timestamp: Instant, error: CoreError },
    MetricRecorded { name: String, value: f64 },
}

pub trait EventHandler: Send + Sync {
    fn handle_event(&self, event: &SystemEvent);
}

// src/core/plugins.rs - Extensibility from day one
pub trait Plugin {
    fn name(&self) -> &str;
    fn version(&self) -> Version;
    fn initialize(&mut self, context: &mut PluginContext) -> Result<(), PluginError>;
}
```

### Core Module Planning Matrix:

| Aspect                  | Current Need | Future Need                          | Core Placement             |
| ----------------------- | ------------ | ------------------------------------ | -------------------------- |
| **Error Types**         | Basic errors | Rich diagnostics, error recovery     | ✅ Base errors in core     |
| **Node Classification** | Parser nodes | Multiple language support            | ✅ NodeKind enum in core   |
| **Configuration**       | File limits  | Runtime configuration, feature flags | ✅ Constants in core       |
| **Metrics**             | None yet     | Performance monitoring               | ✅ Metrics trait in core   |
| **Events**              | None yet     | Event-driven architecture            | ✅ Event system in core    |
| **Protocols**           | LSP only     | Multiple protocol support            | ✅ Protocol traits in core |

### Guidelines for Systems Thinking:

1. **Think in Abstractions**: Design interfaces that can accommodate multiple
   implementations
2. **Plan for Scale**: Consider what happens when your system grows 10x
3. **Identify Patterns**: Look for recurring concepts across different domains
4. **Design for Change**: Make it easy to extend without modifying core
5. **Document Intentions**: Record why something is in core for future
   developers

```rust
// ✅ GOOD - Core module with clear future-oriented design
// src/core/README.md
//! # Core Module Design Principles
//!
//! This module contains shared abstractions designed with future growth in mind:
//!
//! - **traits**: Interfaces enabling multiple implementations (LSP, DAP, custom)
//! - **types**: Domain-agnostic types used across language implementations
//! - **enums**: Standardized classifications preventing semantic drift
//! - **constants**: Centralized configuration for system-wide consistency
//! - **errors**: Hierarchical errors enabling rich diagnostics
//! - **metrics**: Performance measurement (prepared for monitoring features)
//! - **events**: Event system (prepared for reactive architectures)
//! - **plugins**: Extension mechanism (prepared for third-party integrations)
//!
//! When adding to core, ask:
//! 1. Will multiple modules need this?
//! 2. Does this enable future extensibility?
//! 3. Does this standardize a cross-cutting concern?
//! 4. Will this remain stable as the system evolves?
```

## R39: Co-locate trait implementations with trait or struct definition

Trait implementations should reside in the same module as either the trait
definition OR the struct definition, following these guidelines:

```rust
// ✅ GOOD - Implement in struct's module when trait is from core/external
// src/core/traits.rs
pub trait Storage {
    fn read(&self, path: &str) -> Result<Vec<u8>, StorageError>;
    fn write(&mut self, path: &str, data: &[u8]) -> Result<(), StorageError>;
}

// src/storage/filesystem/mod.rs
pub struct FileSystem {
    root: PathBuf,
}

// Implementation co-located with struct
impl crate::core::traits::Storage for FileSystem {
    fn read(&self, path: &str) -> Result<Vec<u8>, StorageError> {
        // Implementation
    }

    fn write(&mut self, path: &str, data: &[u8]) -> Result<(), StorageError> {
        // Implementation
    }
}

// ❌ BAD - Implementation in random location
// src/implementations/storage_impls.rs
impl Storage for FileSystem { ... } // Don't scatter implementations
```

### Guidelines for trait implementation location:

1. **Struct's module**: When implementing external/core traits for your struct
2. **Trait's module**: When implementing your trait for external types
3. **Never scatter**: Don't create separate "impl" modules unrelated to trait
   or struct

```rust
// ✅ GOOD - Implementing local trait for external type
// src/serialization/traits.rs
pub trait JsonSerializable {
    fn to_json(&self) -> String;
}

// Implementation for external type in trait's module
impl JsonSerializable for std::time::Duration {
    fn to_json(&self) -> String {
        format!("{{\"secs\":{}}}", self.as_secs())
    }
}

// ✅ GOOD - Simple example of co-location
// src/core/traits.rs
pub trait Validator {
    fn validate(&self) -> bool;
}

// src/models/user.rs
pub struct User {
    pub name: String,
    pub email: String,
}

// Implementation co-located with struct
impl crate::core::traits::Validator for User {
    fn validate(&self) -> bool {
        !self.name.is_empty() && self.email.contains('@')
    }
}
```

## R40: Split large trait implementations across multiple files

When trait implementations contain many methods or complex logic, split them
across files within an `impl/` subdirectory to maintain the 20-line function
limit.

```rust
// ✅ GOOD - Large trait implementation split across files
// src/storage/filesystem/mod.rs
mod impl_storage;

pub struct FileSystem {
    root: PathBuf,
    cache: Cache,
}

impl FileSystem {
    pub fn new(root: PathBuf) -> Self {
        Self {
            root,
            cache: Cache::new(),
        }
    }
}

// src/storage/filesystem/impl_storage/mod.rs
use super::FileSystem;
use crate::core::traits::Storage;

mod read;
mod write;
mod delete;
mod list;

impl Storage for FileSystem {
    fn read(&self, path: &str) -> Result<Vec<u8>, StorageError> {
        read::read_impl(self, path)
    }

    fn write(&mut self, path: &str, data: &[u8]) -> Result<(), StorageError> {
        write::write_impl(self, path, data)
    }

    fn delete(&mut self, path: &str) -> Result<(), StorageError> {
        delete::delete_impl(self, path)
    }

    fn list(&self, prefix: &str) -> Result<Vec<String>, StorageError> {
        list::list_impl(self, prefix)
    }
}

// src/storage/filesystem/impl_storage/read.rs
use crate::storage::filesystem::FileSystem;  // Use crate:: for multiple levels
use crate::core::errors::StorageError;

pub(super) fn read_impl(fs: &FileSystem, path: &str) -> Result<Vec<u8>, StorageError> {
    // Complex read implementation
    let full_path = fs.root.join(path);

    // Check cache first
    if let Some(cached) = fs.cache.get(path) {
        return Ok(cached);
    }

    // Read from filesystem
    std::fs::read(&full_path)
        .map_err(|e| StorageError::ReadFailed {
            path: path.to_string(),
            source: e,
        })
}
```

### Pattern for organizing split implementations:

```
src/module/
├── mod.rs              # Struct definition and inherent methods
├── impl_trait_name/    # Trait implementation directory
│   ├── mod.rs         # Main impl block that delegates
│   ├── method1.rs     # Complex method implementation
│   ├── method2.rs     # Another complex method
│   └── helpers.rs     # Shared helpers for the implementation
└── tests.rs           # Tests for the module
```

### Guidelines:

1. **Keep delegation simple**: The main impl block should just delegate to
   functions
2. **Use visibility correctly**: Implementation functions should be
   `pub(super)`
3. **Avoid circular dependencies**: Helpers go in the impl module, not parent
4. **Group related methods**: Can group multiple small methods in one file
5. **Document the pattern**: Add a comment explaining the split structure

### When to split vs. keep together:

- **Keep together**: If all methods fit in under 100 lines total
- **Split**: When any single method exceeds 20 lines (R2)
- **Split**: When the trait has 5+ methods with complex logic
- **Split**: When methods have distinct concerns (e.g., read/write/delete)

---

## Common Libraries Pattern

```rust
// Cargo.toml dependencies
[dependencies]
tokio = { version = "1.0", features = ["full"] }
serde = { version = "1.0", features = ["derive"] }
thiserror = "1.0"
miette = { version = "5.0", features = ["fancy"] }
derive_builder = "0.12"
```

## Directory Structure Pattern

```
src/
├── core/                   # System-wide shared abstractions
│   ├── mod.rs             # Core module organization
│   ├── traits.rs          # Shared trait definitions (R32)
│   ├── types.rs           # Shared types and abstractions (R33)
│   ├── errors.rs          # Base error hierarchy (R34-R35)
│   ├── enums.rs           # Shared enum classifications (R36)
│   ├── constants.rs       # System-wide constants (R37)
│   ├── metrics.rs         # Performance metrics traits (future)
│   ├── events.rs          # Event system (future)
│   └── README.md          # Core design principles (R38)
├── storage/
│   ├── mod.rs             # Module exports
│   ├── filesystem/
│   │   ├── mod.rs         # FileSystem struct definition (R39)
│   │   ├── impl_storage/  # Storage trait implementation (R40)
│   │   │   ├── mod.rs     # Main impl block with delegation
│   │   │   ├── read.rs    # read() method implementation
│   │   │   ├── write.rs   # write() method implementation
│   │   │   └── helpers.rs # Shared implementation helpers
│   │   └── errors.rs      # FileSystem-specific errors
│   └── memory/
│       ├── mod.rs         # MemoryStorage struct & impl (R39)
│       └── errors.rs
├── parser/
│   ├── mod.rs             # Re-exports
│   ├── errors.rs          # Parser-specific errors
│   ├── constants.rs       # Parser-specific constants
│   ├── common/
│   │   ├── mod.rs
│   │   ├── traits.rs      # Parser-shared traits
│   │   └── utils.rs       # Parser-shared utilities
│   ├── json/
│   │   ├── mod.rs
│   │   ├── errors.rs
│   │   ├── constants.rs
│   │   └── parser.rs
│   └── xml/
│       ├── mod.rs
│       ├── errors.rs
│       ├── constants.rs
│       └── parser.rs
```

## Testing Pattern

```
tests/
├── parser_common_traits.rs      # Tests src/parser/common/traits.rs
├── parser_json_parser.rs        # Tests src/parser/json/parser.rs
├── parser_xml_parser.rs         # Tests src/parser/xml/parser.rs
├── cmd.rs                       # Tests src/cmd/mod.rs
├── cmd_errors.rs                # Tests src/cmd/errors.rs
├── sdk_python_definition_analyzer.rs  # Tests src/sdk/python/definition/analyzer.rs
└── core_types.rs                # Tests src/core/types.rs
```

## Error Handling Pattern

```rust
#[derive(Debug, Error, Diagnostic)]
pub enum ModuleError {
    #[error("Invalid input: {input}")]
    #[diagnostic(code(module::invalid_input))]
    InvalidInput { input: String },

    #[error("Processing failed: {reason}")]
    #[diagnostic(code(module::process_failed))]
    ProcessFailed { reason: String },

    #[error("IO error occurred")]
    #[diagnostic(code(module::io_error))]
    IoError(#[from] std::io::Error),
}
```

## Functional Style Pattern

```rust
// Functional transformation pipeline
let result: Result<Vec<Document>, ProcessError> = input_files
    .into_iter()
    .map(|path| self.read_file(path))
    .collect::<Result<Vec<_>, _>>()?
    .into_iter()
    .filter(|content| !content.is_empty())
    .map(|content| self.parse_document(content))
    .collect();

// Option/Result combinators
let config = config_path
    .as_ref()
    .map(|path| self.load_config(path))
    .transpose()
    .map_err(|e| ConfigError::LoadFailed(e))?
    .unwrap_or_default();
```

## Trait-Based Design Pattern

```rust
pub trait Parser {
    type Output;
    type Error;

    fn parse(&self, input: String) -> Result<Self::Output, Self::Error>;
}

pub trait Validator {
    fn validate(&self, input: &str) -> bool;
}

pub struct DocumentProcessor<P>
where
    P: Parser + Validator,
{
    parser: P,
}

impl<P> DocumentProcessor<P>
where
    P: Parser + Validator,
{
    pub fn process(&self, input: String) -> Result<P::Output, P::Error> {
        if self.parser.validate(&input) {
            self.parser.parse(input)
        } else {
            Err(P::Error::validation_failed())
        }
    }
}
```

## Core Module Design Pattern (R32-R38)

A comprehensive example showing how all core module rules work together:

```rust
// src/core/mod.rs - Apply systems thinking (R38)
//! Core module designed for current needs and future growth
//!
//! Current: LSP for Python
//! Future: Multiple languages, protocols, and analysis tools

pub mod traits;      // Shared interfaces (R32)
pub mod types;       // Common types (R33)
pub mod errors;      // Error hierarchy (R34-R35)
pub mod enums;       // Shared classifications (R36)
pub mod constants;   // System constants (R37)

// src/core/traits.rs (R32)
pub trait Analyzer {
    type Input;
    type Output;
    type Error: From<crate::core::errors::CoreError>;

    fn analyze(&self, input: Self::Input) -> Result<Self::Output, Self::Error>;
}

// src/core/types.rs (R33)
use serde::{Serialize, Deserialize};

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Location {
    pub uri: String,
    pub range: Range,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Range {
    pub start: Position,
    pub end: Position,
}

// src/core/enums.rs (R36)
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum LanguageId {
    Python,
    Rust,
    JavaScript,
    TypeScript,
    Go,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum AnalysisLevel {
    Syntax,     // Parse only
    Semantic,   // Type checking
    Full,       // All analyses
}

// src/core/constants.rs (R37)
pub mod limits {
    pub const MAX_FILE_SIZE: usize = 50 * 1024 * 1024; // 50MB
    pub const MAX_ANALYSIS_DEPTH: usize = 100;
}

pub mod timeouts {
    use std::time::Duration;
    pub const ANALYSIS: Duration = Duration::from_secs(30);
    pub const PARSE: Duration = Duration::from_secs(5);
}

// src/core/errors.rs (R34-R35)
use thiserror::Error;
use miette::Diagnostic;

#[derive(Debug, Error, Diagnostic)]
pub enum CoreError {
    #[error("File too large: {size} bytes (max: {max})")]
    #[diagnostic(code(core::file_too_large))]
    FileTooLarge { size: usize, max: usize },

    #[error("Analysis timeout after {seconds}s")]
    #[diagnostic(code(core::timeout))]
    Timeout { seconds: u64 },

    #[error("IO error")]
    #[diagnostic(code(core::io))]
    Io(#[from] std::io::Error),
}

// Usage in feature modules:
// src/languages/python/analyzer.rs
use crate::core::{traits::Analyzer, enums::LanguageId, constants::limits};

pub struct PythonAnalyzer {
    language: LanguageId,
}

impl Analyzer for PythonAnalyzer {
    type Input = String;
    type Output = Vec<crate::core::types::Location>;
    type Error = PythonError;

    fn analyze(&self, input: Self::Input) -> Result<Self::Output, Self::Error> {
        if input.len() > limits::MAX_FILE_SIZE {
            return Err(CoreError::FileTooLarge {
                size: input.len(),
                max: limits::MAX_FILE_SIZE,
            }.into());
        }
        // Analysis implementation
        Ok(vec![])
    }
}
```

## Testing Checklist

- [ ] **All files under 100 lines**
- [ ] **All functions under 20 lines**
- [ ] All tests in tests/ directory, never in source files
- [ ] One-to-one mapping between source and test files
- [ ] Test file paths are flattened using underscores (e.g., src/cmd/mod.rs →
      tests/cmd.rs)
- [ ] No unwrap() or expect() in production code
- [ ] Derive macros used instead of manual implementations
- [ ] Traits defined for extensibility and flexibility
- [ ] Struct methods preferred over standalone functions
- [ ] Enums used instead of string constants for classification
- [ ] Constants defined instead of magic strings
- [ ] Functional combinators used over imperative control flow
- [ ] Each module directory has errors.rs file
- [ ] All modules are directories, not single files
- [ ] Common functionality centralized in common/ directories
- [ ] Iterator chains used for data transformation
- [ ] Proper use of &self, &mut self, and self in methods
- [ ] Trait objects used appropriately for runtime polymorphism
- [ ] Generic functions defined with proper trait bounds
- [ ] Owned types preferred over references for simplicity
- [ ] Only single super:: used; crate:: for multiple levels up
- [ ] Shared traits placed in core modules to avoid cross-dependencies
- [ ] Shared types and abstractions centralized in core modules
- [ ] Hierarchical error types defined with automatic conversion
- [ ] Error propagation uses #[from] for seamless conversion up the hierarchy
- [ ] Shared enums placed in core for consistent classification
- [ ] Constants centralized in core modules with clear documentation
- [ ] Systems thinking applied when planning core module content
- [ ] Trait implementations co-located with trait or struct definition
- [ ] Large trait implementations split across files when needed

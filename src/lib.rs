//! # Template RS
//!
//! A generic Rust template project with CLI and logging infrastructure.

// Re-export commonly used types for convenience
pub use miette::{miette, Result};
pub use tokio;
pub use tracing::{debug, error, info, trace, warn};

// Public modules
// Add your library modules here as needed

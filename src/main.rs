use clap::{Parser, ValueEnum};
use miette::Result;
use tracing::{info, Level};
use tracing_subscriber::FmtSubscriber;

mod cmd;
use cmd::Command;

#[derive(Debug, Clone, ValueEnum)]
pub enum LogLevel {
    Trace,
    Debug,
    Info,
    Warn,
    Error,
}

impl From<LogLevel> for Level {
    fn from(level: LogLevel) -> Self {
        match level {
            LogLevel::Trace => Level::TRACE,
            LogLevel::Debug => Level::DEBUG,
            LogLevel::Info => Level::INFO,
            LogLevel::Warn => Level::WARN,
            LogLevel::Error => Level::ERROR,
        }
    }
}

#[derive(Parser, Debug)]
#[command(name = "template-rs")]
#[command(version, about, long_about = None)]
pub struct Cli {
    /// Set the logging level
    #[arg(long, value_enum, default_value_t = LogLevel::Info)]
    pub log_level: LogLevel,

    #[command(subcommand)]
    pub command: Option<Command>,
}

fn setup_logging(level: LogLevel) -> Result<()> {
    let subscriber = FmtSubscriber::builder()
        .with_max_level(Level::from(level))
        .finish();

    tracing::subscriber::set_global_default(subscriber)
        .map_err(|e| miette::miette!("Failed to set up logging: {}", e))?;

    Ok(())
}

#[tokio::main]
async fn main() -> Result<()> {
    let cli = Cli::parse();

    setup_logging(cli.log_level)?;

    info!("Starting template-rs");

    match cli.command {
        Some(_cmd) => {
            // Command handling would go here
            info!("Command handling not yet implemented");
        }
        None => {
            info!("No command specified");
        }
    }

    Ok(())
}

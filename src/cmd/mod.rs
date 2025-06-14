use clap::Subcommand;

#[derive(Subcommand, Debug)]
pub enum Command {
    #[command(hide = true)]
    _Placeholder,
}

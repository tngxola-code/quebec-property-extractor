"""PropLedger command line."""

from __future__ import annotations

import typer

from propledger import __version__

app = typer.Typer(help="PropLedger Quebec command line")


@app.command()
def version() -> None:
    """Print the installed version."""
    typer.echo(__version__)


if __name__ == "__main__":
    app()

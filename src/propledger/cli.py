"""PropLedger command line."""
from __future__ import annotations

import typer

app = typer.Typer(help="PropLedger Quebec command line")


@app.command()
def version() -> None:
    """Print the installed version."""
    from propledger import __version__

    typer.echo(__version__)


if __name__ == "__main__":
    app()

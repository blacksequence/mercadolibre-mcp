from __future__ import annotations

from io import StringIO
from unittest import TestCase
from unittest.mock import patch

from mercadolibre_mcp import main


class ConsoleScriptTests(TestCase):
    def test_version_flag_prints_version_and_does_not_start_server(self) -> None:
        stdout = StringIO()
        with (
            patch.object(main.sys, "argv", ["mercadolibre-mcp", "--version"]),
            patch.object(main.sys, "stdout", stdout),
            patch.object(main.mcp, "run") as mcp_run,
        ):
            main.run()

        mcp_run.assert_not_called()
        self.assertEqual(stdout.getvalue(), f"mercadolibre-mcp {main.__version__}\n")

    def test_without_flags_starts_stdio_server(self) -> None:
        with (
            patch.object(main.sys, "argv", ["mercadolibre-mcp"]),
            patch.object(main.mcp, "run") as mcp_run,
        ):
            main.run()

        mcp_run.assert_called_once_with(transport="stdio")

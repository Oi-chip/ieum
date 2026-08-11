import subprocess
import sys
import unittest
from pathlib import Path


PROJECT_DIR = Path(__file__).resolve().parents[2]


class PackageImportTest(unittest.TestCase):
    def test_server_app_can_be_imported_from_project_root(self):
        result = subprocess.run(
            [
                sys.executable,
                "-c",
                (
                    "from server.app import app; "
                    "routes = {rule.rule for rule in app.url_map.iter_rules()}; "
                    "assert '/api/bus/nearby' in routes; "
                    "assert '/api/hospitals/nearby' in routes"
                ),
            ],
            cwd=PROJECT_DIR,
            capture_output=True,
            text=True,
            timeout=10,
            check=False,
        )

        self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == "__main__":
    unittest.main()

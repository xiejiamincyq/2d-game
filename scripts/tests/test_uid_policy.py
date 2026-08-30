from pathlib import Path
import unittest


PROJECT_ROOT = Path(__file__).resolve().parents[2]
SOURCE_ROOTS = (PROJECT_ROOT / "assets", PROJECT_ROOT / "scripts")


class UidPolicyTest(unittest.TestCase):
    def test_every_godot_source_has_a_uid_sidecar(self) -> None:
        sources = []
        for root in SOURCE_ROOTS:
            sources.extend(root.rglob("*.gd"))
            sources.extend(root.rglob("*.gdshader"))

        missing = [path for path in sources if not Path(f"{path}.uid").is_file()]
        self.assertEqual([], missing)

    def test_uid_sidecars_are_valid_unique_and_not_orphaned(self) -> None:
        uid_files = []
        for root in SOURCE_ROOTS:
            uid_files.extend(root.rglob("*.uid"))

        values = {}
        problems = []
        for uid_path in uid_files:
            source_path = Path(str(uid_path)[:-4])
            value = uid_path.read_text(encoding="utf-8").strip()
            if not source_path.is_file():
                problems.append(f"orphaned: {uid_path.relative_to(PROJECT_ROOT)}")
            if not value.startswith("uid://") or not value[6:].isalnum():
                problems.append(f"invalid: {uid_path.relative_to(PROJECT_ROOT)}")
            if value in values:
                problems.append(
                    "duplicate: "
                    f"{uid_path.relative_to(PROJECT_ROOT)} and "
                    f"{values[value].relative_to(PROJECT_ROOT)}"
                )
            values[value] = uid_path

        self.assertEqual([], problems)

    def test_uid_line_endings_are_stable_in_git(self) -> None:
        attributes = (PROJECT_ROOT / ".gitattributes").read_text(encoding="utf-8")
        self.assertIn("*.uid text eol=lf", attributes.splitlines())


if __name__ == "__main__":
    unittest.main()

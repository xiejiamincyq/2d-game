from pathlib import Path
import unittest


PROJECT_ROOT = Path(__file__).resolve().parents[2]


class ProjectStatusDocsTest(unittest.TestCase):
    def test_readme_matches_the_six_wave_runtime(self) -> None:
        readme = (PROJECT_ROOT / "README.md").read_text(encoding="utf-8")

        self.assertIn("六个普通波次", readme)
        self.assertNotIn("五个递进阶段", readme)

    def test_current_release_readiness_has_verified_facts(self) -> None:
        readiness = (
            PROJECT_ROOT
            / "docs"
            / "release"
            / "2026-08-30-release-readiness.md"
        ).read_text(encoding="utf-8")

        for fact in (
            "分支：`5分钟超载`",
            "50 个 Godot 测试套件",
            "91,836 次断言",
            "4,442,628 字节",
            "6 个普通波次",
        ):
            self.assertIn(fact, readiness)

    def test_old_release_checklist_is_clearly_historical(self) -> None:
        old_checklist = (
            PROJECT_ROOT
            / "docs"
            / "release"
            / "2026-07-26-phase6-release-checklist.md"
        ).read_text(encoding="utf-8")

        self.assertIn("历史快照", old_checklist)

    def test_main_todo_starts_with_the_current_status(self) -> None:
        todo = (PROJECT_ROOT / "tasks" / "todo.md").read_text(encoding="utf-8")

        self.assertIn("## 2026-08-30 状态更新", todo)


if __name__ == "__main__":
    unittest.main()

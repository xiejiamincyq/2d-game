from pathlib import Path
import unittest


PROJECT_ROOT = Path(__file__).resolve().parents[2]


class ProjectStatusDocsTest(unittest.TestCase):
    def test_readme_distinguishes_current_endless_source_from_old_packages(self) -> None:
        readme = (PROJECT_ROOT / "README.md").read_text(encoding="utf-8")
        current = readme.split("## F12与更早阶段的历史记录", 1)[0]
        self.assertIn("六关为一轮", current)
        self.assertIn("金币与继承能力", current)
        self.assertIn("不再提供旧波次兼容入口", current)
        self.assertIn("campaign-endless-upgrade-progress-v1.md", current)
        self.assertIn("本轮自动验收完成", current)
        self.assertIn("campaign-endless-final-audit-v1.md", current)
        self.assertIn("不是人类完整通关", current)
        self.assertNotIn("尚未完成最终验收", current)
        audit = (PROJECT_ROOT / "docs/campaign-endless-final-audit-v1.md").read_text(encoding="utf-8")
        self.assertIn("418套Godot", audit)
        self.assertIn("完整12段", audit)
        self.assertTrue((PROJECT_ROOT / "docs/performance/campaign-endless-final-v1/evidence.zip").is_file())
        self.assertNotIn("保留旧波次兼容模式", current)
        self.assertNotIn("当前六关原生骨骼工程与验证已完成", current)

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

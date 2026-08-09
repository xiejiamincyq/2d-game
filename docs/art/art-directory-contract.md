# 美术目录与生成物合同

## 目录职责

- `assets/art/source/`：高分辨率母图、模型和可追溯源文件；运行时不得直接加载。
- `assets/art/actors|effects|pickups|environment|ui/`：经过验证的 Godot 运行时资源。1024×1024 母图不能仅靠节点缩放冒充 64×64 运行时输出。
- `docs/art/previews/`：供用户选择和审查的预览，不得被游戏加载。
- `docs/art/manifests/`：生成合同、来源和审批状态；状态必须与台账一致。
- `docs/art/reviews/`：人工审查结论和运行时证据索引。
- `tmp/`：本地截图、中间生成物和可丢弃检查文件，不提交。
- Git 历史：被否决或被替代方案的长期归档。除非确有离线需求，不在运行时目录复制 archive 版本。

## 生成边界

- 每个运行时 Asset ID 只有一个权威 production manifest。
- 每次实质修订使用新版本文件名，禁止覆盖已批准产物。
- `.import`、`__pycache__` 和本地生成缓存不进入版本控制。
- `.gd.uid` 是 Godot 稳定资源标识，不属于缓存，不应统一忽略。
- 旧玩家 72/120 帧图集在替代方案接入前仅作临时兼容；不得继续生成新帧或升高审批状态。

## 审批边界

- `style-approved` 至少要求运行时文件存在、production manifest 状态一致。
- `gameplay-approved` 另需实际战斗 capture、Alpha 报告和 review 文档，路径写入 `runtime_evidence`。
- 自动测试提供证据，但不能替代用户对实际游戏画面的确认。
- 使用 `python scripts/art/validate_asset_registry.py` 在每次审批和提交前校验。

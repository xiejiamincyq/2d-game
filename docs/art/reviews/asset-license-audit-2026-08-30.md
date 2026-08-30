# 美术资产许可证审计

日期：2026-08-30

## 结论

当前 47 份美术 manifest 中，45 份为 `license_review_state: pending`，2 份程序化资产为 `not-applicable`。本次审计不把任何生成资产提升为 `approved`，因为仍存在模型条款、输入引用和发行地域需要由项目所有者确认的条件。

这是一份工程侧来源审计，不是法律意见。公开发行前应由项目所有者或专业法律顾问确认最终发行地区、账户适用条款、第三方输入权利和随包通知要求。

## 来源分类

| 分类 | Manifest 数量 | 当前判断 |
|---|---:|---|
| OpenAI 图像生成派生 | 34 | 输出权利取决于实际账户条款；项目仍需确认所有输入参考拥有必要权利 |
| Tencent Hunyuan3D 派生 | 4 | 存在明确地域、使用和规模条件；当前不能批准全球发行 |
| 本地确定性或程序化 | 9 | 其中 2 项无第三方生成来源；其余 7 项依赖上游生成资产，不能单独解除上游限制 |

六份静态敌人生产 manifest 的精确 provider 提示词没有被历史流程保留。本轮以 `prompt_lineage_state: reconstructed-brief-exact-provider-prompt-unavailable` 明确记录，只补充可由现存源图、风格锁和运行证据确认的生产 brief，没有冒充原始提示词。

## OpenAI 输出

当前 OpenAI Services Agreement 说明：在适用法律允许的范围内，客户保留输入权利并拥有输出；同时客户必须对输入具备必要权利，并自行负责输出的使用和适用性。因此，“使用内置 imagegen”本身不足以证明整个资产链可以发行，还需要确认生成时账户适用的具体条款和每个参考输入的权利。

证据：<https://cdn.openai.com/osa/openai-services-agreement.pdf>

## Tencent Hunyuan3D-2mv

项目 manifest 明确记录使用 `tencent/Hunyuan3D-2mv` 生成玩家转身模型，并由该模型继续产生当前 M2 运行图集。其社区许可证：

- 将适用地域限定为不含欧盟、英国和韩国的区域；
- 对作品、输出和结果的使用及分发设置地域限制；
- 产品月活超过 100 万时需要另行向 Tencent 申请授权；
- 要求遵守可接受使用政策，并可能要求向后续接收者传递相关限制或通知。

证据：<https://huggingface.co/tencent/Hunyuan3D-2mv/blob/main/LICENSE>

因此当前玩家资源不能直接按“全球无限制发行”批准。发行前必须二选一：

1. 由项目所有者确认发行地域、规模和通知方式完全满足该许可证，并保存书面审查记录；或
2. 用不继承 Hunyuan 输出的自有/明确商业授权模型重建玩家源模型及三张运行图集。

## Prompt Library 引用

6 份 manifest 含 prompt-library ID。项目管线将这些引用限定为构图或提示参考，而不是美术源文件；但仍需确认实际生成输入没有复制受限制图片或超出允许范围使用第三方表达。

## 发行门禁

- [ ] 确认生成 OpenAI 图像时适用的账户条款，并保存条款版本和日期。
- [ ] 审核所有参考图片和 prompt-library 输入，只保留具有明确使用权的来源。
- [ ] 对 Hunyuan 派生玩家资源完成地域/通知审查，或完成无 Hunyuan 依赖的替代烘焙。
- [ ] 为最终发行包加入所有适用的第三方 LICENSE/NOTICE。
- [ ] 上述记录完成后，逐份把允许发行的 manifest 从 `pending` 更新为 `approved`；只有届时才能把对应 `review_state` 提升为 `final`。

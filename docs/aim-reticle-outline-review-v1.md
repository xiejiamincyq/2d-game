# 准心黑色外描边验收（2026-10-07）

用户指定黑色描边，保留既有24px尺寸、奶白内芯、瞄准中心、输入穿透和显隐规则，无新增位图或风格选择。四条黑色6px底线向两端各延长2px；2px内芯禁用抗锯齿，避免微小准心边缘被奶白抗锯齿污染。

原始证据位于本机 ignored `build/diagnostics/gameplay-feedback-v2/`：

- `reticle-red-v2`：真实退出1，仅黑色要求失败；最初v1为ready时机错误，不计有效红测。
- `reticle-green-v2`：AimReticleOutlineTest 8、UITest 89，退出0且无引擎/脚本/泄漏错误。
- 原生Vulkan `reticle-before-v2.png`：32个黑边采样全部失败；黑边初稿after-v1仍有16个抗锯齿污染采样失败，保留记录。
- `reticle-after-v2.png`：原生实际截图，32个1×侧边/端点采样全部通过，SHA256 `3bbae45396a208fb84b00261bd60cc8c25f3344f190bc39e2e41f510ad08fc15`。同图1.5×在白、奶油、薄荷、深绿背景的目检通过，不将它冒称自动像素验证。

独立只读审查：Critical 0 / Required 0；无新增节点、纹理或依赖，仍每帧四方向各两次绘制。原生图已由作者与审查者分别查看。此局部验收不是全游戏手感或所有分辨率验收；中央测试入口随本轮完整玩法提交接入。

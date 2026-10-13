# 当前生产美术与输入来源签收

状态：**当前资源通过自主生产美术/输入来源审查**，不是真人认可、专业法律意见、公开发行或整个Goal完成。依据用户明确授予的自主风格/审批权限；新墨线纸偶方向优先于旧技能模板的位图尺寸/旧风格要求，继续遵守真实骨骼、轮廓、透明度、握枪、运行证据和来源规则。不为代码原生资源伪造PNG生产manifest。

## 精确版本及资源覆盖

本次签收仅适用于[24身体候选清单](final-native-production-candidate-v1.json)，该文件SHA `fdbe39a4db6850be51f46e07fff7fc5eb0d30d3f52f2373da362e816fbd37480`。24个当前场景、27个外置动作库和24份历史对应manifest逐SHA复核无漂移。玩家前后左右为一角色四库；7基础敌人、8新增区域敌人、6章节Boss、1兼容独立Boss、玩家及无人机，共24独立身体。不重复计历史版本或工厂中同身体的多role。

全部24资源均能对应**passed且场景/全部动作库SHA相同**的GPU资源报告。对应表在 `final-native-production-evidence-v1/resource-visual-bindings.json`；报告只匹配资源本体，保留原报告的历史consumer和采样范围，绝不宣称历史全部依赖仍当前。完整当前消费者由347 Godot/330300、独立22夹具/6949及新的真实六关链补足。

| 当前组 | 资源/动作审核依据 |
| --- | --- |
| 玩家/无人机 | 四向身体、手骨枪口、各方向七动作；无人机五动作。相同资源的独立alpha/连续报告，当前真实移动射击与包流程 |
| 15敌人身体 | 真实Skeleton2D/Bone2D、权重、rest、所需动作有多关节变化；普通预警/各攻击/受击/死亡及大型延后门的专项；同资源名册与动作报告 |
| 六区域Boss | 各自14基础/三招分段片段的契约、对应本体GPU和权威Actor时钟/取消/暂停/死亡测试，当前新档六次真实首领胜利 |
| 兼容独立Boss | root_overseer独立23骨/21片段，五招各warning/attack/recovery和转阶段；资源及真实Actor专项、当前纯PCK覆盖 |

本轮再次实际查看同资源名册行走、潮壳动作、书记连续关键姿态、兼容Boss姿态表；兼容表展示工具缩放，不能据缩略图检查每个关节细节，详细原图/连续与Actor专项保持。结合此前逐族动作审图和[当前六关中段采样](final-six-chapter-visual-sampling-v1.md)，接受原生Q版轮廓、区域身份、动作分工、血条/小感叹号、手持枪和不透明身体。不是逐帧全组合或真人动作审美保证。

## 当前运行美术输入来源

- 角色：各技术Shapes/Draft脚本以自写顶点、颜色、骨链和关键帧构造；例如RootlingPaperShapes、PlayerPaperDraft/PlayerPaperMotion、RangerDroneShapes、BellPriestShapes、RiftObserverShapes。共用描边/蒙皮工具不是共用外部角色。当前24场景/27库没有外置Texture/Image/Font/Audio/Video ext_resource；这一文本检查本身不足证明原创，和作者输入登记、制作过程及实际包目录联合使用。
- 地图/环境/菜单：六区原生Floor/Prop与种子地图、CampaignBackdrop/Theme/RegionIcon、新兼容地面/四prop都是本项目代码几何/shader；不复制《暗黑地牢》角色、衣装或画面，只采用逐关压力/选择的通用设计思路。实际区域结构、碰撞与可绕行另由地图/移动专项验证，不能用版权记录替代玩法验证。
- 效果/声音：PaperImpactArt为八顶点四尖原生纸星，其余当前区域原生危险/弹丸有独立源；OriginalOverdriveCue生成22050Hz、0.18秒单声道PCM，不采样旧MP3。字体使用系统字体，不把用户系统字体文件重新分发。
- 免费参考：[Kenney Monster Builder](https://kenney.nl/assets/monster-builder-pack)和[Kenney Roguelike/RPG](https://kenney.nl/assets/roguelike-rpg-pack)原作品页本轮再次明确标CC0。前者仅拆件技术样板，后者仅一般布局参考；不把“免费”当许可证，不把技术样板当生产原创角色。已下载样板许可证/原hash保留，未再次下载或购买。
- 实际PCK的587目录项中外置图片/纹理缓存/音频/字体文件匹配0，制作source/docs不进入包，24身体27动作库在；PCK SHA `a8b2e96408be3b7e438a09a683121a7ca0266bb8b9d9c3667c2d8f5fcb1a8ea6`。PCK目录只能证明确实退役，不能单独保证任何作品法律权利。

裁决：对上述**当前原创运行输入**接受项目内使用的来源审核；没有选用付费作品，没有提取付费资源或安装新工具。不擅自把项目原创成果改成CC0，不自动许可整个仓库，也不为未来公开发行作法律保证。旧PNG、Pixabay未明确作品的MP3、原manifest/source的pending状态全部保留，不假批来源；它们不在当前正式运行包中。

## 审批记录与整体边界

本签收是新的当前消费者记录，不覆写33份包含历史版本的Actor声明、冻结23-rig授权门、旧失败或source-bank SHA。那些文件里的draft/style状态是当时局部状态，不能批量改写破坏后续攻击制作的真实时序。本记录不绕过原NativeCatalog/PNG验证器，也不偷偷改变运行时可用列表。

密集性能仅当前首关单seed/本机，见[性能边界](../../performance/campaign-final-f8-v1.md)。独立发行EXE目前只有实际启动/菜单渲染，发行保护不执行外置脚本，缺PASS的失败记录保留；源引擎六关正常输入与引擎加载同PCK首章流程不能冒称发行EXE的OS鼠标/Windows瞄准或真人手感。最终完整要求核对、Git范围/提交推送及真实操作未验证项的明确交接仍需收尾。未公开发布。

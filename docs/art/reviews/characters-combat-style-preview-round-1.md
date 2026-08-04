# 角色与战斗风格预览：第一轮

## 状态

- 风格门：`Checkpoint ART-A`
- 当前状态：等待用户选择
- 可选方向：`A`、`B`、`C`，也可指定组合特征或要求新一轮预览
- `review_state`：`draft`
- 禁止事项：用户选择前不得扩展正式角色批次

## 固定比较条件

- 内容：玩家、Scrapper、Bruiser、基础命中火花。
- 布局：左上玩家、右上 Scrapper、左下 Bruiser、右下命中火花。
- 镜头：俯视三分之四视角。
- 阵营色：玩家青、敌人洋红、玩家武器和命中橙。
- 目标尺寸：标准角色约 64×64，Bruiser 约 96×96。

## A：战术图形插画

![预览 A](../previews/characters-combat/style-preview-a-v1.png)

- 优势：轮廓最干净，装甲分面和阵营色清晰，小尺寸最稳。
- 取舍：质感较规整，废土拼装感和磨损层次较少。
- Manifest：`../manifests/characters-combat/player_base.preview-a.json`

## B：废土手绘工业

![预览 B](../previews/characters-combat/style-preview-b-v1.png)

- 优势：氧化、积尘、织物和修补痕迹最丰富，废土感最强。
- 取舍：小尺寸下内部纹理较密，需要在正式稿中主动删减细节。
- Manifest：`../manifests/characters-combat/player_base.preview-b.json`

## C：微缩 PBR 模型

![预览 C](../previews/characters-combat/style-preview-c-v1.png)

- 优势：立体体块、磨损材质和小尺寸轮廓较均衡，Bruiser 体量感最好。
- 取舍：若继续提高高光或真实感，可能滑向过度光滑的模型展示风格。
- Manifest：`../manifests/characters-combat/player_base.preview-c.json`

## 缩小对比

此图将每张 1536×1024 预览缩至 384×256，用于检查接近运行时尺寸时的轮廓和色彩层级。

![运行时缩小对比](../previews/characters-combat/style-preview-runtime-comparison-v1.png)

## 已发现问题

- 三个方向的 Scrapper 都被生成成持枪单位，与当前近战追击玩法不一致。
- 本轮只用于选择材质、体块、光照和细节密度，不批准具体装备设计。
- 用户选择方向后，下一张风格锁定稿必须将 Scrapper 改为无枪、短程近战、前向追击轮廓。
- 当前预览为不透明背景的风格板，不代表最终透明 PNG 已完成。

## 参考谱系

本轮只把以下公开示例作为构图或材质提示参考，未把它们作为项目风格权威：

- A：`Sci-Fi Tactical Soldier Character Sheet`，YouMind prompt `27303`。
- B：`Archive Recovery Operative Character Sheet`，YouMind prompt `25446`。
- C：`Hyper-Realistic 3D CGI Collectible Figurine Prompt for Nano Banana 2`，YouMind prompt `12837`。

完整生成提示词、示例图 URL、负面约束和模型记录在对应 manifest 中。

## 用户决定

- 选择：待定
- 保留特征：待定
- 拒绝特征：待定
- 需要重做：待定

# 推箱子 Sokoban

这是一个用 Flutter 编写的推箱子游戏。当前工程包含可游玩的内置关卡、自定义关卡导入、本地关卡持久化、提示求解、死局检测，以及一个用于设计和导出关卡的桌面 Python/Tkinter 生成器。

## 当前功能

### 关卡选择

- 首页为关卡选择页，标题为 `选择关卡`。
- 关卡按分组展示：
  - `内置关卡`：来自代码内置关卡目录。
  - `自定义关卡`：来自本地导入保存的 JSON 关卡。
- 内置关卡以关卡编号显示。
- 自定义关卡以 `自定义 1`、`自定义 2` 等顺序显示。
- 点击关卡卡片后进入对应关卡。
- 右上角 `导入关卡` 按钮可以导入 JSON 内容或 JSON 文件路径。
- 自定义关卡加载中、加载失败、空列表都会有页面状态提示。

### 游戏页面

- 游戏页面标题显示 `推箱子 - 关卡标题`，过关后显示 `已过关`。
- 顶部信息栏显示：
  - 当前关卡编号。
  - 当前步数。
- 棋盘按关卡实际行列数生成视口，并根据屏幕空间等比缩放。
- 支持不同尺寸的矩形布局，不再绑定固定 10 x 15 棋盘。
- 棋盘元素包括空白区域、墙体、地板、箱子、目标点、目标点上的箱子和玩家。
- 棋盘单元格带有语义标签，便于测试和辅助功能识别。

### 操作方式

- 屏幕方向按钮：
  - 上、下、左、右移动玩家。
- 键盘：
  - `ArrowUp`、`ArrowDown`、`ArrowLeft`、`ArrowRight` 移动。
  - `W`、`A`、`S`、`D` 移动。
  - `Z` 或 `Ctrl+Z` 撤销一步。
- AppBar 按钮：
  - 撤销一步。
  - 重置本关。
- 玩家只能在可通行地面移动。
- 玩家推箱子时，一次只能推动一个箱子。
- 箱子后方不是可通行地面，或已有箱子时，推动无效。
- 每次有效移动都会增加步数。
- 撤销会恢复玩家位置、箱子位置和步数。
- 重置会恢复当前关卡初始状态。

### 过关、死局和提示

- 当所有目标点上都有箱子时判定过关。
- 过关弹窗提供：
  - 留在本关。
  - 下一关；如果已经是最后一关，则重玩本关。
- 进入关卡和每次推动箱子后会检查关卡状态。
- 当前实现会检测：
  - 箱子被推入无法到达目标点的死格。
  - 箱子形成不可解的 2 x 2 锁死块。
- 死局时弹窗提示建议撤销或重置。
- `提示` 按钮会运行推箱子搜索：
  - 已完成：提示本关已经完成。
  - 找到路径：给出下一次推动建议，并在棋盘上高亮箱子、推动方向和下一格位置。
  - 无解：提示当前局面找不到可通关路径。
  - 搜索上限：提示当前局面较复杂，建议撤销或重置。
- 游戏页提示搜索上限目前为 `8000` 个访问状态。

### 自定义关卡导入

- 关卡选择页右上角可以导入关卡。
- 导入弹窗支持两种输入：
  - 直接粘贴 JSON 内容。
  - 输入本机 JSON 文件路径，可带单引号或双引号。
- 输入以 `{` 或 `[` 开头时会按 JSON 内容处理；否则按文件路径处理。
- JSON 文件和 JSON 内容大小限制为 `64 KB`。
- 导入成功后：
  - 关卡会追加到 `自定义关卡` 分组。
  - 页面会显示导入成功提示。
  - 关卡会写入本地持久化文件，重启后仍可加载。
- 导入失败时会显示具体原因，不会写入本地关卡库。

## 运行项目

先安装 Flutter SDK，并确保当前环境可以运行目标平台。

```powershell
flutter pub get
flutter run -d windows
```

如果要运行 Android：

```powershell
flutter run -d android
```

运行测试：

```powershell
flutter test
```

静态分析：

```powershell
dart analyze
```

## 项目结构

```text
lib/
  main.dart
  src/
    sokoban_app.dart
    game/
      sokoban_rules.dart
    input/
      game_intents.dart
    levels/
      advanced_levels.dart
      custom_level_import_source.dart
      custom_level_limits.dart
      custom_level_store.dart
      introductory_levels.dart
      intermediate_levels.dart
      level_catalog.dart
      level_copy.dart
      sokoban_level_import.dart
      sokoban_levels.dart
    models/
      board_position.dart
      board_tile.dart
      board_viewport_size.dart
      game_snapshot.dart
      sokoban_level.dart
    ui/
      level_selection_page.dart
      movement_controls.dart
      sokoban_board.dart
      sokoban_tile.dart
      sokoban_wall_page.dart
tools/
  sokoban_level_generator.py
  generated_levels/
docs/
  custom_level_import_design.md
test/
```

### 主要入口

- `lib/main.dart`：Flutter 程序入口，启动 `SokobanApp`。
- `lib/src/sokoban_app.dart`：配置 MaterialApp、主题和首页。
- `lib/src/ui/level_selection_page.dart`：关卡选择、自定义关卡加载和导入入口。
- `lib/src/ui/sokoban_wall_page.dart`：核心游戏页，处理移动、撤销、重置、过关、死局和提示。
- `lib/src/ui/sokoban_board.dart`：按布局渲染棋盘视口。
- `lib/src/ui/sokoban_tile.dart`：渲染单个棋盘格。
- `lib/src/ui/movement_controls.dart`：屏幕方向控制按钮。

## 关卡系统

### 内置关卡来源

- `lib/src/levels/introductory_levels.dart`：当前实际启用的内置关卡列表。
- `lib/src/levels/intermediate_levels.dart`：预留中级关卡列表，目前为空。
- `lib/src/levels/advanced_levels.dart`：预留高级关卡列表，目前为空。
- `lib/src/levels/sokoban_levels.dart`：汇总当前要启用的内置关卡。
- `lib/src/levels/level_catalog.dart`：把内置关卡包装成统一目录项。
- `lib/src/levels/level_copy.dart`：关卡标题和描述文案数据。

当前 `sokobanLevels` 的定义为：

```dart
final List<SokobanLevel> sokobanLevels = [...introductoryLevels];
```

也就是说当前内置可玩关卡来自 `introductoryLevels`。测试中期望内置关卡数量为 `40`。

### 关卡数据模型

关卡使用 `SokobanLevel` 表示：

```dart
class SokobanLevel {
  const SokobanLevel({
    required this.number,
    required this.title,
    required this.description,
    required this.layout,
    required this.initialPlayerPosition,
    this.hintTexts = const [],
  });
}
```

字段说明：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `number` | `int` | 关卡编号，用于展示 |
| `title` | `String` | 关卡标题 |
| `description` | `String` | 关卡描述 |
| `layout` | `List<String>` | 棋盘布局，每个字符串是一行 |
| `initialPlayerPosition` | `BoardPosition` | 玩家初始坐标，行列从 `0` 开始 |
| `hintTexts` | `List<String>` | 预留文本提示，目前游戏页使用自动求解提示 |

### 关卡目录模型

`LevelCatalogItem` 用于统一表示内置关卡和自定义关卡：

```dart
enum LevelSource { builtIn, custom }

class LevelCatalogItem {
  const LevelCatalogItem({
    required this.id,
    required this.source,
    required this.level,
  });
}
```

- 内置关卡 ID 格式为 `built_in_关卡编号`。
- 自定义关卡 ID 由导入时间和序号生成。
- 游戏页可以接收外部注入的 `levelCatalog`，因此自定义关卡也能复用同一套游玩逻辑。

### 棋盘符号

App 内部和 JSON 导入支持以下布局符号：

| 符号 | 含义 |
| --- | --- |
| `_` | 棋盘外或空白区域，不可行走 |
| 空格 | 地板，可行走 |
| `#` | 墙体，不可行走 |
| `B` | 箱子 |
| `T` | 目标点 |
| `*` | 已在目标点上的箱子，同时计入箱子和目标点 |

实现细节：

- `tileAt` 会把 `_` 识别为空白区域，把 `#` 识别为墙体，其他布局字符按地板处理。
- `positionsForSymbol(layout, 'B')` 会把 `B` 和 `*` 都计入箱子。
- `positionsForSymbol(layout, 'T')` 会把 `T` 和 `*` 都计入目标点。
- 导入校验只允许 `_`、空格、`#`、`B`、`T`、`*`。

### 关卡合法性规则

导入关卡和游戏加载时会校验关键约束：

- `layout` 不能为空。
- 每一行长度必须一致，布局必须是矩形。
- 至少有一个箱子。
- 至少有一个目标点。
- 箱子数量必须等于目标点数量。
- 玩家初始位置不能越界。
- 玩家初始位置必须在可通行地块上。
- 玩家初始位置不能和箱子重叠。
- 开局箱子不能落在明确死格上。
- 可选校验可以要求关卡可解，并限制可解性检测的最大箱子数量。

## 自定义关卡 JSON 格式

标准 JSON 示例：

```json
{
  "number": 41,
  "title": "自定义关卡",
  "description": "把箱子推到目标点。",
  "layout": [
    "#####",
    "#   #",
    "# B #",
    "# T #",
    "#   #",
    "#####"
  ],
  "initialPlayerPosition": {
    "row": 1,
    "column": 1
  }
}
```

字段要求：

| 字段 | 类型 | 必需 | 说明 |
| --- | --- | --- | --- |
| `number` | `int` | 是 | 展示编号，不作为唯一 ID |
| `title` | `string` | 是 | 标题；空白标题会回退为 `自定义关卡` |
| `description` | `string` | 是 | 描述 |
| `layout` | `string[]` | 是 | 矩形布局 |
| `initialPlayerPosition.row` | `int` | 是 | 玩家初始行，从 `0` 开始 |
| `initialPlayerPosition.column` | `int` | 是 | 玩家初始列，从 `0` 开始 |

导入入口会调用：

- `CustomLevelImportSourceReader.read`：判断输入是 JSON 文本还是文件路径。
- `CustomLevelStore.importLevelJson`：限制大小、解析、写入本地关卡库。
- `parseImportedSokobanLevelJson`：解析 JSON。
- `validateImportedSokobanLevel`：执行结构和玩法合法性校验。

## 自定义关卡保存位置

自定义关卡保存为本地 JSON 文件。默认保存文件名为 `custom_levels.json`。

平台默认路径：

| 平台 | 默认目录 |
| --- | --- |
| Windows | `%APPDATA%\Sokoban\custom_levels\custom_levels.json` |
| macOS | `$HOME/Library/Application Support/Sokoban/custom_levels.json` |
| Linux | `$XDG_DATA_HOME/Sokoban/custom_levels.json`，没有 `XDG_DATA_HOME` 时为 `$HOME/.local/share/Sokoban/custom_levels.json` |
| 其他 | 系统临时目录下的 `Sokoban/custom_levels.json` |

存储文件结构：

```json
{
  "schemaVersion": 1,
  "levels": [
    {
      "id": "custom_20260513_101112_013_001",
      "schemaVersion": 1,
      "importedAt": "2026-05-13T10:11:12.013",
      "level": {
        "number": 91,
        "title": "导入测试",
        "description": "从测试导入。",
        "layout": [],
        "initialPlayerPosition": {
          "row": 1,
          "column": 1
        }
      }
    }
  ]
}
```

目前已实现导入和加载；删除、重命名、批量导入、导出自定义关卡还没有在 App UI 中实现。

## 关卡生成器脚本

脚本位置：

```text
tools/sokoban_level_generator.py
```

运行命令：

```powershell
python tools\sokoban_level_generator.py
```

该脚本是桌面 Tkinter GUI 工具，用于设计、导入和导出推箱子关卡。它不属于 Flutter App 运行时依赖，但用于制作内置关卡和生成可导入 JSON。

### 脚本运行环境

- Python 3。
- Tkinter。
- Windows 的常见 Python 安装通常自带 Tkinter。
- Linux 如果缺少 Tkinter，需要先安装系统包，例如 `python3-tk`。

### 脚本默认配置

| 配置 | 值 |
| --- | --- |
| 默认行数 | `10` |
| 默认列数 | `15` |
| 最大行数 | `40` |
| 最大列数 | `40` |
| 单元格大小 | `30` |
| 默认导出目录 | `tools/generated_levels` |
| 关卡编号范围 | `1` 到 `999` |

脚本启动时会扫描 `tools/generated_levels`，从已有 JSON、Dart 片段或文件名中提取关卡编号，然后自动给出下一个编号。

### 编辑工具

左侧工具栏包含 6 种工具：

| 快捷键 | 工具 | 写入符号 | 说明 |
| --- | --- | --- | --- |
| `1` | 墙体 | `#` | 设置不可穿过墙 |
| `2` | 地板 | 空格 | 设置可行走地面 |
| `3` | 棋盘外 | `_` | 设置棋盘外空白区域 |
| `4` | 人 | 不写入布局符号 | 设置玩家初始位置 |
| `5` | 箱子 | `B` 或 `*` | 在目标点上放箱子时变为 `*` |
| `6` | 目标点 | `T` 或 `*` | 在箱子上放目标点时变为 `*` |

鼠标操作：

- 左键点击或拖拽：使用当前工具绘制。
- 右键点击：擦除为地板。

矩阵操作：

- `重建矩阵`：按输入行列重新创建棋盘。
- `清空为地板`：把当前矩阵全部变成地板，并清空玩家位置。
- `生成外框墙`：给矩阵边界填充墙体。

快捷键：

- `1` 到 `6`：切换工具。
- `Ctrl+S`：导出 Dart 片段。
- `Ctrl+O`：导入 JSON/Dart。

### 脚本导入功能

点击 `导入 JSON/Dart` 可以导入已有关卡文件。

支持文件类型：

- `.json`
- `.txt`
- `.dart`
- 其他文本文件也可以尝试导入

导入 JSON 时读取标准关卡 JSON。

导入 Dart 或文本时，脚本会尝试解析：

- `number: 数字`
- `title: '标题'` 或 `title: "标题"`
- `description: '描述'` 或 `description: "描述"`
- `layout: [...]`
- `initialPlayerPosition: BoardPosition(row: x, column: y)`

脚本导入支持比 App 更宽松的符号，并会归一化：

| 导入符号 | 归一化结果 |
| --- | --- |
| `_` | 棋盘外 |
| 空格 | 地板 |
| `#` | 墙 |
| `B`、`$` | 箱子 |
| `T`、`.` | 目标点 |
| `*` | 目标点上的箱子 |
| `P`、`p`、`@` | 玩家在地板上 |
| `+` | 玩家在目标点上 |

导入时如果发现问题，会尽量载入并给出警告：

- 布局行长度不一致时，短行会用地板补齐。
- 多个玩家符号时，只保留第一个。
- `layout` 中玩家符号与 `initialPlayerPosition` 不一致时，优先使用 `initialPlayerPosition`。
- `initialPlayerPosition` 越界时，会尝试使用布局中的玩家符号。
- 缺少玩家、箱子、目标点或数量不一致时会给出提示。

### 脚本导出 JSON

点击 `导出 JSON` 会生成 App 可导入的 JSON 文件。

默认文件名：

```text
level_041.json
```

默认目录：

```text
tools/generated_levels
```

导出前脚本会校验：

- 必须放置玩家。
- 玩家必须在地板或目标点上。
- 玩家不能在墙体、棋盘外、箱子或目标点上的箱子上。
- 至少需要一个箱子。
- 至少需要一个目标点。
- 箱子数量必须等于目标点数量。

导出的 JSON 可以直接在 App 的 `导入关卡` 弹窗中粘贴，或输入文件路径导入。

### 脚本导出 Dart 片段

点击 `导出 Dart 片段` 会生成 `SokobanLevel(...)` 代码片段，并复制到剪贴板。

默认文件名：

```text
level_041.dart.txt
```

导出片段示例：

```dart
SokobanLevel(
  number: 41,
  title: '第41关',
  description: '把箱子推到目标点。',
  layout: [
    '#####',
    '#   #',
    '# B #',
    '# T #',
    '#   #',
    '#####',
  ],
  initialPlayerPosition: BoardPosition(row: 1, column: 1),
),
```

如需把关卡做成内置关卡：

1. 使用生成器导出 Dart 片段。
2. 将片段加入 `lib/src/levels/introductory_levels.dart`，或加入新的关卡列表文件。
3. 如果使用新的列表文件，需要在 `lib/src/levels/sokoban_levels.dart` 中合并它。
4. 确保文件已导入 `BoardPosition` 和 `SokobanLevel`。
5. 运行 `flutter test` 检查关卡结构、可解性和页面渲染。

### 当前生成物目录

`tools/generated_levels` 存放生成器导出的草稿文件。

当前目录中包含：

- 多个 `level_XXX.dart.txt` Dart 片段。
- 少量 `level_XXX.json` JSON 关卡文件。

这些文件不会自动进入内置关卡列表。要游玩它们，可以：

- 在 App 中导入对应 JSON。
- 或把 Dart 片段复制到内置关卡列表中。

## 关卡相关 Dart 模块

### `sokoban_rules.dart`

核心规则和搜索逻辑位于：

```text
lib/src/game/sokoban_rules.dart
```

主要能力：

| 函数或类型 | 功能 |
| --- | --- |
| `cardinalDirections` | 上、下、左、右四个方向 |
| `tileAt` | 根据布局字符返回地块类型 |
| `positionsForSymbol` | 扫描某种符号的位置集合，`B` 和 `T` 会包含 `*` |
| `isInsideLayout` | 判断坐标是否在布局范围内 |
| `isFloorTile` | 判断坐标是否是可通行地块 |
| `isSolvedState` | 判断箱子集合是否已经覆盖全部目标点 |
| `positionsKey` | 把位置集合转成稳定字符串 key |
| `searchStateKey` | 把玩家位置和箱子集合转成搜索状态 key |
| `computeDeadTiles` | 反向从目标点搜索，找出箱子无法到达目标点的死格 |
| `computeReachableFloors` | 在当前箱子布局下，计算玩家可达地板 |
| `formsFrozenSquareDeadlock` | 判断箱子是否形成 2 x 2 锁死块 |
| `isSokobanStateSolvable` | 广度搜索判断当前状态是否存在通关路径 |
| `findNextSokobanPushHint` | 搜索下一次推动建议，用于游戏页提示 |

示例：判断一个关卡是否可解。

```dart
final bricks = positionsForSymbol(level.layout, 'B');
final targets = positionsForSymbol(level.layout, 'T');
final deadTiles = computeDeadTiles(level.layout, targets);

final solvable = isSokobanStateSolvable(
  layout: level.layout,
  playerPosition: level.initialPlayerPosition,
  brickPositions: bricks,
  targetPositions: targets,
  deadTiles: deadTiles,
);
```

示例：获取下一步提示。

```dart
final result = findNextSokobanPushHint(
  layout: level.layout,
  playerPosition: playerPosition,
  brickPositions: brickPositions,
  targetPositions: targetPositions,
  deadTiles: deadTiles,
  maxVisitedStates: 8000,
);
```

### `sokoban_level_import.dart`

导入解析和校验位于：

```text
lib/src/levels/sokoban_level_import.dart
```

主要能力：

| 类型或函数 | 功能 |
| --- | --- |
| `SokobanLevelValidationOptions` | 控制导入校验选项 |
| `SokobanLevelImportException` | 导入失败异常，包含中文错误信息 |
| `parseImportedSokobanLevelJson` | 同步解析 JSON 字符串为 `SokobanLevel` |
| `parseImportedSokobanLevelJsonAsync` | 异步解析 JSON 字符串 |
| `validateImportedSokobanLevel` | 校验关卡结构、坐标、符号、箱子数量、死格和可选可解性 |

可选校验参数：

| 参数 | 说明 |
| --- | --- |
| `maxRows` | 限制最大行数 |
| `maxColumns` | 限制最大列数 |
| `requireSolvable` | 是否要求导入时验证可解 |
| `maxBoxesForSolvability` | 可解性检测允许的最大箱子数量，默认 `8` |

示例：

```dart
final level = parseImportedSokobanLevelJson(
  jsonSource,
  options: const SokobanLevelValidationOptions(
    maxRows: 40,
    maxColumns: 40,
    requireSolvable: true,
    maxBoxesForSolvability: 8,
  ),
);
```

### `custom_level_import_source.dart`

输入源读取位于：

```text
lib/src/levels/custom_level_import_source.dart
```

主要能力：

- 去除输入前后空白。
- 空输入直接失败。
- 输入看起来像 JSON 时直接返回文本。
- 输入不是 JSON 时按文件路径读取。
- 支持去除路径外层单引号或双引号。
- 文件不存在时给出错误。
- 文件超过 `64 KB` 时拒绝。
- 文件按 UTF-8 读取。

### `custom_level_store.dart`

自定义关卡存储位于：

```text
lib/src/levels/custom_level_store.dart
```

主要能力：

- `loadCatalogItems`：读取本地自定义关卡库，转成 `LevelCatalogItem` 列表。
- `importLevelJson`：校验 JSON、生成内部 ID、写入本地关卡库并返回目录项。
- 自动创建存储目录。
- 读写格式使用缩进 JSON。
- 如果存储文件损坏，会抛出带中文说明的 `CustomLevelStoreException`。

### `custom_level_limits.dart`

当前只定义一个共享限制：

```dart
const int customLevelImportMaxBytes = 64 * 1024;
```

导入源读取和关卡存储都会使用这个限制。

## 新增关卡建议流程

### 作为自定义关卡游玩

1. 运行生成器：

   ```powershell
   python tools\sokoban_level_generator.py
   ```

2. 设计关卡并导出 JSON。
3. 启动 Flutter App。
4. 在关卡选择页点击右上角导入按钮。
5. 粘贴 JSON 内容，或输入 JSON 文件路径。
6. 导入成功后在 `自定义关卡` 分组点击游玩。

### 作为内置关卡提交到代码

1. 使用生成器导出 Dart 片段。
2. 把 `SokobanLevel(...)` 添加到合适的关卡列表。
3. 确认 `sokoban_levels.dart` 已包含该列表。
4. 检查关卡编号、标题和描述。
5. 确保布局矩形、箱子和目标点数量一致、玩家位置合法。
6. 运行测试：

   ```powershell
   flutter test
   ```

7. 如果测试失败，根据错误提示修正布局或坐标。

## 测试说明

当前测试文件覆盖范围：

| 文件 | 覆盖内容 |
| --- | --- |
| `test/widget_test.dart` | 内置关卡结构、唯一布局、可解性、关卡选择页、游戏页渲染、自定义 JSON 导入流程 |
| `test/sokoban_level_import_test.dart` | JSON 解析、字段缺失、非矩形布局、非法字符、数量不一致、玩家坐标、超尺寸选项、`*` 符号 |
| `test/custom_level_store_test.dart` | 自定义关卡导入、持久化重载、无效 JSON 不写入 |
| `test/sokoban_hint_test.dart` | 下一步提示搜索、死局状态、提示按钮弹窗 |
| `test/level_catalog_test.dart` | 内置关卡目录包装、游戏页目录注入 |

常用命令：

```powershell
flutter test
dart analyze
```

## 当前限制

- App 内还没有自定义关卡删除、重命名、排序、重新导出功能。
- App 导入 JSON 时只接受标准布局符号；生成器可以导入更宽松的符号，但导出给 App 时应使用标准符号。
- App 端导入默认不强制执行完整可解性搜索，只做结构、数量、坐标和死格等基础校验。
- 大关卡会等比缩放显示；当前没有棋盘拖拽、缩放或滚动查看功能。
- `intermediate_levels.dart` 和 `advanced_levels.dart` 已预留，但当前为空，且未合并进 `sokobanLevels`。

## 参考文档

- `docs/custom_level_import_design.md`：自定义关卡导入设计说明和后续扩展方向。

# 箱径项目代码详解

本文基于当前仓库代码整理，覆盖项目结构、框架依赖、运行流程、核心函数、参数、状态管理、推箱子规则、导入存储、UI 渲染、测试和辅助工具链。文档以源码实际实现为准；如果与旧文档不一致，应优先相信源码。

## 1. 项目概览

`箱径` 是一个 Flutter 推箱子游戏。运行时代码主要在 `lib/` 下，平台壳代码在 `android/` 和 `windows/`，关卡和标准答案以 Flutter assets 的形式放在 `tools/generated_levels/` 和 `tools/solution_levels/`。

核心能力包括：

- 关卡选择页：分为内置关卡和自定义关卡。
- 游戏页：显示棋盘、步数、撤销、重置、提示、过关弹窗。
- 规则引擎：移动、推箱子、死格、死锁、可解性搜索、下一步提示搜索。
- 关卡导入：支持粘贴 JSON 或输入本机 JSON 文件路径。
- 自定义关卡持久化：写入本地 `custom_levels.json`。
- 工具链：Python/Tkinter 关卡编辑器、Python 求解器、Dart 标准答案生成器、PowerShell 图标生成器。

当前重要事实：

- `pubspec.yaml` 把 `tools/generated_levels/` 和 `tools/solution_levels/` 注册为 Flutter assets。
- 内置关卡不是写死在某个 Dart 列表中，而是由 `lib/src/levels/sokoban_levels.dart` 从 `tools/generated_levels/` 读取 `.json` 和 `.dart.txt` 资源生成。
- `README.md` 中仍提到 `introductory_levels.dart`，但当前仓库没有这个文件；当前实现应以 assets 加载逻辑为准。
- 当前 `tools/generated_levels/` 有 36 个关卡文件，`tools/solution_levels/` 有 36 个标准答案文件。

## 2. 技术栈与依赖

### 2.1 Flutter 与 Dart

配置文件：`pubspec.yaml`

```yaml
environment:
  sdk: ^3.11.5
```

项目使用 Flutter Material 3，入口是 `lib/main.dart`。

### 2.2 运行时依赖

| 依赖 | 版本 | 代码中的用途 |
| --- | --- | --- |
| `flutter` | SDK | Flutter UI、Material、路由壳、assets |
| `cupertino_icons` | `^1.0.8` | 当前源码没有直接引用，保留在模板依赖中 |
| `flutter_riverpod` | `^3.3.1` | 全局状态管理，Provider、FutureProvider、AsyncNotifier、Notifier |
| `go_router` | `^17.2.3` | 页面路由：关卡选择页和游戏页 |
| `flutter_animate` | `^4.5.2` | 关卡卡片进入动画 |
| `lucide_icons_flutter` | `^3.1.14+1` | AppBar、按钮、提示、方向键等图标 |
| `shared_preferences` | `^2.5.5` | 当前源码没有直接引用；自定义关卡使用 `dart:io` JSON 文件保存 |

### 2.3 开发与测试依赖

| 依赖 | 用途 |
| --- | --- |
| `flutter_test` | Widget 测试和单元测试 |
| `flutter_lints` | Flutter 推荐 lint 集 |

### 2.4 原生与工具技术

| 目录或文件 | 技术 |
| --- | --- |
| `android/` | Gradle Kotlin DSL、Android Manifest、Kotlin MainActivity |
| `windows/` | CMake、C++ Windows runner |
| `tools/sokoban_level_generator.py` | Python 3、Tkinter |
| `tools/sokoban_level_solver.py` | Python 3、A* / 搜索算法 |
| `tools/generate_app_icons.ps1` | PowerShell、`System.Drawing` |
| `tool/generate_sokoban_standard_solutions.dart` | Dart CLI |

## 3. 目录结构

```text
lib/
  main.dart
  src/
    app_branding.dart
    sokoban_app.dart
    app/
      router.dart
      theme.dart
    controllers/
      game_controller.dart
      level_catalog_controller.dart
    game/
      sokoban_rules.dart
    input/
      game_intents.dart
    levels/
      advanced_levels.dart
      custom_level_import_source.dart
      custom_level_limits.dart
      custom_level_store.dart
      intermediate_levels.dart
      level_catalog.dart
      level_copy.dart
      sokoban_level_import.dart
      sokoban_levels.dart
      sokoban_standard_solutions.dart
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
tool/
  generate_sokoban_standard_solutions.dart
tools/
  generate_app_icons.ps1
  sokoban_level_generator.py
  sokoban_level_solver.py
  generated_levels/
  solution_levels/
test/
docs/
android/
windows/
```

代码分层可以理解为：

| 层级 | 代表文件 | 职责 |
| --- | --- | --- |
| 应用入口 | `main.dart`, `sokoban_app.dart` | 启动 Flutter、注入 ProviderScope、配置 MaterialApp |
| 路由与主题 | `app/router.dart`, `app/theme.dart` | 页面路径、页面切换动画、主题 |
| 控制器 | `controllers/*.dart` | Riverpod 状态、关卡目录、自定义导入、游戏状态 |
| 领域规则 | `game/sokoban_rules.dart` | 推箱子规则、死局、求解、提示 |
| 数据模型 | `models/*.dart` | 坐标、棋盘格、关卡、快照、视口 |
| 关卡系统 | `levels/*.dart` | assets 加载、标准答案、JSON 解析、持久化 |
| UI | `ui/*.dart` | 页面、棋盘、单元格绘制、移动控件 |
| 工具 | `tool/`, `tools/` | 生成关卡、生成标准答案、生成图标 |

## 4. 启动与运行流程

### 4.1 程序入口

文件：`lib/main.dart`

```dart
void main() {
  runApp(const SokobanApp());
}
```

`main` 没有额外初始化逻辑，只负责把根组件交给 Flutter。

### 4.2 根组件

文件：`lib/src/sokoban_app.dart`

`SokobanApp` 是项目根组件。

构造参数：

| 参数 | 类型 | 默认值 | 作用 |
| --- | --- | --- | --- |
| `key` | `Key?` | Flutter 默认 | Widget 标识 |
| `customLevelStore` | `CustomLevelStore?` | `null` | 测试或特殊场景中替换自定义关卡存储 |

`SokobanApp.build` 做两件事：

1. 创建 `ProviderScope`。
2. 如果传入 `customLevelStore`，覆盖 `customLevelStoreProvider`。

这使测试可以使用内存存储或挂起存储，不污染真实本地文件。

内部 `_SokobanMaterialApp` 是 `ConsumerWidget`，通过 `ref.watch(appRouterProvider)` 读取 `GoRouter`，然后构造：

```dart
MaterialApp.router(
  debugShowCheckedModeBanner: false,
  title: appName,
  theme: buildSokobanTheme(),
  routerConfig: router,
)
```

### 4.3 页面路由

文件：`lib/src/app/router.dart`

`AppRoute` 枚举：

| 值 | name | path | 页面 |
| --- | --- | --- | --- |
| `home` | `home` | `/` | `LevelSelectionPage` |
| `level` | `level` | `/level/:index` | `SokobanWallPage` |

`appRouterProvider` 是 `Provider<GoRouter>`。它定义两条路由：

- `/`：直接返回关卡选择页。
- `/level/:index`：从 path parameter 解析关卡索引，失败时回退为 `0`。

游戏页使用 `CustomTransitionPage<void>`，过渡函数是 `_levelTransition`。

`_levelTransition` 参数：

| 参数 | 类型 | 作用 |
| --- | --- | --- |
| `context` | `BuildContext` | Flutter 上下文 |
| `animation` | `Animation<double>` | 主页面进入动画 |
| `secondaryAnimation` | `Animation<double>` | 次级动画，当前未使用 |
| `child` | `Widget` | 待显示页面 |

实现效果：

- `Curves.easeOutCubic` 淡入。
- 从右侧极轻微偏移 `Offset(0.04, 0)` 滑入。

## 5. 品牌、主题与输入意图

### 5.1 品牌文案

文件：`lib/src/app_branding.dart`

```dart
const String appName = '箱径';
```

`appLevelTitle(String levelTitle, {bool isComplete = false})`

| 参数 | 类型 | 默认值 | 说明 |
| --- | --- | --- | --- |
| `levelTitle` | `String` | 必填 | 当前关卡标题 |
| `isComplete` | `bool` | `false` | 是否已过关 |

返回格式：

- 未过关：`箱径 - 关卡标题`
- 已过关：`箱径 - 关卡标题 已过关`

### 5.2 主题

文件：`lib/src/app/theme.dart`

`buildSokobanTheme()` 返回 `ThemeData`。

主要设置：

- `ColorScheme.fromSeed(seedColor: Color(0xFF526652))`
- 页面背景：`Color(0xFFF2EFE7)`
- Material 3：`useMaterial3: true`
- AppBar：深绿色背景、白色前景、标题不居中
- FilledButton、IconButton、Card：统一 8px 圆角

### 5.3 键盘意图

文件：`lib/src/input/game_intents.dart`

`MoveIntent`

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `rowOffset` | `int` | 行方向偏移，向上为 `-1`，向下为 `1` |
| `columnOffset` | `int` | 列方向偏移，向左为 `-1`，向右为 `1` |

`UndoIntent` 无参数，用于撤销一步。

这些 Intent 在 `SokobanWallPage` 的 `Shortcuts` 和 `Actions` 中使用。

## 6. 数据模型

### 6.1 BoardPosition

文件：`lib/src/models/board_position.dart`

表示棋盘坐标，采用从 `0` 开始的行列坐标。

构造参数：

| 参数 | 类型 | 说明 |
| --- | --- | --- |
| `row` | `int` | 行 |
| `column` | `int` | 列 |

字段：

- `row`
- `column`

方法：

`move(int rowOffset, int columnOffset)`

| 参数 | 类型 | 说明 |
| --- | --- | --- |
| `rowOffset` | `int` | 行偏移 |
| `columnOffset` | `int` | 列偏移 |

返回一个新 `BoardPosition`，不会修改原对象。

重写：

- `operator ==`：两个坐标 row 和 column 都相等即相等。
- `hashCode`：使用 `Object.hash(row, column)`，因此可放入 `Set<BoardPosition>` 或作为 Map key。

### 6.2 BoardTile

文件：`lib/src/models/board_tile.dart`

```dart
enum BoardTile { empty, wall, floor, brick }
```

| 值 | 含义 |
| --- | --- |
| `empty` | 棋盘外或空白区域 |
| `wall` | 墙体 |
| `floor` | 可行走地面，包括普通地面和目标点底面 |
| `brick` | 箱子，实际由动态箱子集合决定 |

注意：目标点不是 `BoardTile` 枚举值，而是通过 `targetPositions` 集合叠加表示。

### 6.3 BoardViewportSize

文件：`lib/src/models/board_viewport_size.dart`

用于描述棋盘可见区域大小。

构造参数：

| 参数 | 类型 | 约束 | 说明 |
| --- | --- | --- | --- |
| `rows` | `int` | `> 0` | 可见行数 |
| `columns` | `int` | `> 0` | 可见列数 |

属性：

| 属性 | 类型 | 说明 |
| --- | --- | --- |
| `aspectRatio` | `double` | `columns / rows`，游戏页用它保持棋盘比例 |

工厂方法：

`BoardViewportSize.forLayout(List<String> layout, {Iterable<BoardPosition> visiblePositions = const []})`

| 参数 | 说明 |
| --- | --- |
| `layout` | 关卡字符串矩阵 |
| `visiblePositions` | 强制纳入可见范围的动态点，例如玩家、箱子、目标点、提示格 |

它内部调用 `BoardViewportRegion.forLayout(...).size`。

静态方法：

`supportsLayout(List<String> layout)`

返回布局是否至少有一行且至少有一列。

### 6.4 BoardViewportRegion

同文件：`board_viewport_size.dart`

描述可见区域在原始布局中的起点和尺寸。

构造参数：

| 参数 | 类型 | 约束 | 说明 |
| --- | --- | --- | --- |
| `firstRow` | `int` | `>= 0` | 可见区域第一行 |
| `firstColumn` | `int` | `>= 0` | 可见区域第一列 |
| `rows` | `int` | `> 0` | 可见行数 |
| `columns` | `int` | `> 0` | 可见列数 |

属性：

- `lastRow = firstRow + rows - 1`
- `lastColumn = firstColumn + columns - 1`
- `size = BoardViewportSize(rows: rows, columns: columns)`

工厂方法：

`BoardViewportRegion.forLayout(List<String> layout, {Iterable<BoardPosition> visiblePositions = const []})`

算法：

1. 扫描布局中不是空格 `' '` 且不是下划线 `'_'` 的格子，作为可见锚点。
2. 把传入的 `visiblePositions` 中仍在布局内部的点也纳入范围。
3. 如果没有任何可见锚点，则退回整张布局的最大行列范围。
4. 返回最小包围矩形。

私有辅助：

- `_isVisibleLayoutAnchor(String cell)`：非空格且非 `_` 就视为可见。
- `_isInsideLayout(List<String> layout, BoardPosition position)`：判断坐标是否在布局实际字符串范围内。

### 6.5 GameSnapshot

文件：`lib/src/models/game_snapshot.dart`

用于撤销功能，保存一次移动前的状态。

构造参数：

| 参数 | 类型 | 说明 |
| --- | --- | --- |
| `playerPosition` | `BoardPosition` | 玩家坐标 |
| `brickPositions` | `Set<BoardPosition>` | 箱子坐标集合，构造时复制 |
| `stepCount` | `int` | 当时步数 |

`brickPositions` 会通过 `Set.from` 复制，避免外部集合被后续修改影响历史记录。

### 6.6 SokobanLevel

文件：`lib/src/models/sokoban_level.dart`

关卡数据对象。

构造参数：

| 参数 | 类型 | 默认值 | 说明 |
| --- | --- | --- | --- |
| `number` | `int` | 必填 | 展示编号 |
| `title` | `String` | 必填 | 关卡标题 |
| `description` | `String` | 必填 | 关卡描述 |
| `layout` | `List<String>` | 必填 | 棋盘布局，每个字符串是一行 |
| `initialPlayerPosition` | `BoardPosition` | 必填 | 玩家初始坐标 |
| `hintTexts` | `List<String>` | `const []` | 文本提示预留字段，当前游戏页主要使用自动求解提示 |

属性：

`displayName` 返回 `Level $number — $title`，测试错误信息中会使用。

## 7. 关卡布局符号

当前 Dart 规则和导入校验使用这些标准符号：

| 符号 | 含义 | 是否可行走底面 |
| --- | --- | --- |
| `_` | 棋盘外或空白区域 | 否 |
| 空格 | 地板 | 是 |
| `#` | 墙 | 否 |
| `B` | 箱子所在格 | 是，箱子动态叠加 |
| `T` | 目标点 | 是 |
| `*` | 箱子已经在目标点上 | 是，同时计入箱子和目标点 |

实现细节：

- `tileAt` 只把 `_` 当作 `empty`，把 `#` 当作 `wall`，其他字符都当作 `floor`。
- `positionsForSymbol(layout, 'B')` 会匹配 `B` 和 `*`。
- `positionsForSymbol(layout, 'T')` 会匹配 `T` 和 `*`。
- 玩家位置不写在 `layout` 字符串中，而是单独存储在 `SokobanLevel.initialPlayerPosition`。

## 8. 关卡目录与加载

### 8.1 LevelSource 与 LevelCatalogItem

文件：`lib/src/levels/level_catalog.dart`

`LevelSource`

| 值 | 含义 |
| --- | --- |
| `builtIn` | 内置关卡 |
| `custom` | 用户导入的自定义关卡 |

`LevelCatalogItem`

构造参数：

| 参数 | 类型 | 默认值 | 说明 |
| --- | --- | --- | --- |
| `id` | `String` | 必填 | 内部唯一 ID |
| `source` | `LevelSource` | 必填 | 来源 |
| `level` | `SokobanLevel` | 必填 | 关卡本体 |
| `standardSolution` | `List<SokobanPushHint>` | `const []` | 标准答案推箱步骤，仅内置关卡通常有 |

### 8.2 loadBuiltInLevelCatalog

```dart
Future<List<LevelCatalogItem>> loadBuiltInLevelCatalog({AssetBundle? bundle})
```

参数：

| 参数 | 类型 | 默认值 | 说明 |
| --- | --- | --- | --- |
| `bundle` | `AssetBundle?` | `null` | 用于测试注入；为空时使用 `rootBundle` |

流程：

1. 调用 `loadSokobanLevels` 从 `tools/generated_levels/` 加载关卡。
2. 调用 `loadBuiltInSokobanStandardSolutions` 从 `tools/solution_levels/` 加载标准答案。
3. 调用 `buildBuiltInLevelCatalog` 包装成目录项。

### 8.3 buildBuiltInLevelCatalog

```dart
List<LevelCatalogItem> buildBuiltInLevelCatalog(
  List<SokobanLevel> levels, {
  Map<int, List<SokobanPushHint>> standardSolutions = const {},
})
```

参数：

| 参数 | 类型 | 说明 |
| --- | --- | --- |
| `levels` | `List<SokobanLevel>` | 内置关卡列表 |
| `standardSolutions` | `Map<int, List<SokobanPushHint>>` | 以关卡 `number` 为 key 的标准答案 |

返回不可变列表。ID 格式为：

```text
built_in_1
built_in_2
...
```

注意：ID 中的数字来自列表索引，而标准答案查找使用 `SokobanLevel.number`。

### 8.4 从 assets 加载生成关卡

文件：`lib/src/levels/sokoban_levels.dart`

常量：

```dart
const String generatedLevelAssetDirectory = 'tools/generated_levels/';
```

`loadSokobanLevels({AssetBundle? bundle})`

流程：

1. 从 `AssetManifest` 读取所有 assets。
2. 过滤路径以 `tools/generated_levels/` 开头，且后缀是 `.json` 或 `.dart.txt` 的文件。
3. 按路径排序。
4. 并行读取每个 asset 字符串。
5. `.json` 使用 `parseImportedSokobanLevelJson`。
6. `.dart.txt` 使用 `parseGeneratedSokobanLevelDartSnippet`。
7. 使用 `_deduplicateExactLevels` 去重。
8. 按关卡编号和 asset path 排序。
9. 返回不可变 `List<SokobanLevel>`。

解析使用的校验选项：

```dart
const SokobanLevelValidationOptions(validateInitialDeadTiles: false)
```

也就是说，生成关卡资源加载时不拒绝初始死格。原因通常是为了兼容生成器或半成品资源；正式导入用户关卡时默认会校验初始死格。

重要私有函数：

| 函数 | 参数 | 作用 |
| --- | --- | --- |
| `_isGeneratedLevelAsset` | `String assetPath` | 判断是否是生成关卡 asset |
| `_parseGeneratedLevelAsset` | `assetPath`, `source` | 根据后缀选择 JSON 或 Dart 片段解析 |
| `_deduplicateExactLevels` | `List<_LoadedSokobanLevel>` | 按完整关卡内容去重 |
| `_levelIdentityKey` | `SokobanLevel level` | 生成去重 key，包含编号、标题、描述、玩家坐标和布局 |
| `_assetPriority` | `String assetPath` | JSON 优先级高于 Dart 片段 |
| `_compareLoadedLevels` | 两个 `_LoadedSokobanLevel` | 先按关卡编号，再按路径排序 |

### 8.5 标准答案加载

文件：`lib/src/levels/sokoban_standard_solutions.dart`

常量：

```dart
const String sokobanSolutionAssetDirectory = 'tools/solution_levels/';
```

`loadBuiltInSokobanStandardSolutions({AssetBundle? bundle})`

返回：

```dart
Future<Map<int, List<SokobanPushHint>>>
```

流程：

1. 从 AssetManifest 中找 `tools/solution_levels/*.txt`。
2. 文件名必须匹配 `level_(数字).txt`。
3. 读取文件内容。
4. 用 `parseSokobanStandardSolution` 解析。
5. 空答案不写入 Map。
6. 返回不可变 Map。

`parseSokobanStandardSolution(String source)`

格式：

```text
2,3,U;2,2,L
```

分隔符：分号或空白字符。

每个推箱步骤由三部分组成：

| 部分 | 例子 | 含义 |
| --- | --- | --- |
| row | `2` | 箱子当前行 |
| column | `3` | 箱子当前列 |
| direction | `U` | 推动方向 |

方向编码：

| 编码 | BoardPosition |
| --- | --- |
| `U` | `row: -1, column: 0` |
| `D` | `row: 1, column: 0` |
| `L` | `row: 0, column: -1` |
| `R` | `row: 0, column: 1` |

## 9. 自定义关卡导入与存储

### 9.1 导入大小限制

文件：`lib/src/levels/custom_level_limits.dart`

```dart
const int customLevelImportMaxBytes = 64 * 1024;
```

此限制同时用于：

- 从文件路径读取 JSON。
- 保存前检查粘贴的 JSON 内容。

### 9.2 CustomLevelImportSourceReader

文件：`lib/src/levels/custom_level_import_source.dart`

`CustomLevelImportSourceReader.read(String input)`

参数：

| 参数 | 类型 | 说明 |
| --- | --- | --- |
| `input` | `String` | 用户在导入弹窗输入的内容，可以是 JSON 文本，也可以是文件路径 |

流程：

1. `trim()` 去除两端空白。
2. 空字符串抛出 `SokobanLevelImportException('导入内容不能为空。')`。
3. 如果以 `{` 或 `[` 开头，直接当作 JSON 文本返回。
4. 否则当作文件路径。
5. 支持去除路径外层单引号或双引号。
6. 文件不存在则报错。
7. 文件大小超过 64 KB 则报错。
8. 以 UTF-8 读取并返回文件内容。

私有函数：

- `_looksLikeJson(String input)`：判断是否以 `{` 或 `[` 开头。
- `_unquoteFilePath(String path)`：去掉成对外层引号。

### 9.3 JSON 解析与校验

文件：`lib/src/levels/sokoban_level_import.dart`

#### SokobanLevelValidationOptions

构造参数：

| 参数 | 类型 | 默认值 | 说明 |
| --- | --- | --- | --- |
| `maxRows` | `int?` | `null` | 最大行数限制 |
| `maxColumns` | `int?` | `null` | 最大列数限制 |
| `validateInitialDeadTiles` | `bool` | `true` | 是否拒绝开局箱子在死格 |
| `requireSolvable` | `bool` | `false` | 是否执行完整可解性搜索 |
| `maxBoxesForSolvability` | `int` | `8` | 可解性搜索允许的最大箱子数量 |

#### SokobanLevelImportException

字段：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `message` | `String` | 面向用户的中文错误 |

`toString()` 返回 `message`，因此 UI 直接拼接异常对象时会显示中文错误。

#### parseImportedSokobanLevelJson

```dart
SokobanLevel parseImportedSokobanLevelJson(
  String source, {
  SokobanLevelValidationOptions options = const SokobanLevelValidationOptions(),
})
```

参数：

| 参数 | 说明 |
| --- | --- |
| `source` | JSON 字符串 |
| `options` | 校验选项 |

流程：

1. `jsonDecode(source)`。
2. JSON 格式错误时抛出 `JSON 无法解析。`。
3. 根节点不是对象时抛出 `关卡 JSON 根节点必须是对象。`。
4. `_levelFromPayload` 提取字段。
5. `validateImportedSokobanLevel` 校验。
6. 如果存在错误，只抛出第一条错误。
7. 返回 `SokobanLevel`。

#### parseImportedSokobanLevelJsonAsync

异步包装：

```dart
Future<SokobanLevel> parseImportedSokobanLevelJsonAsync(...)
```

它先 `await Future<void>.delayed(Duration.zero)`，让调用方异步让出事件循环，然后调用同步解析函数。

#### parseGeneratedSokobanLevelDartSnippet

```dart
SokobanLevel parseGeneratedSokobanLevelDartSnippet(
  String source, {
  SokobanLevelValidationOptions options = const SokobanLevelValidationOptions(),
})
```

解析生成器导出的 Dart 片段，例如：

```dart
SokobanLevel(
  number: 41,
  title: '第41关',
  description: '把箱子推到目标点。',
  layout: [
    '#####',
  ],
  initialPlayerPosition: BoardPosition(row: 1, column: 1),
)
```

它通过正则读取：

- `number`
- `title`
- `description`
- `layout`
- `initialPlayerPosition`

然后复用同一套 `validateImportedSokobanLevel`。

#### validateImportedSokobanLevel

```dart
List<String> validateImportedSokobanLevel(
  SokobanLevel level, {
  SokobanLevelValidationOptions options = const SokobanLevelValidationOptions(),
})
```

返回错误字符串列表，不直接抛异常。

校验规则：

1. `layout` 不能为空。
2. 如果传入 `maxRows`，行数不能超过限制。
3. 第一行不能为空。
4. 如果传入 `maxColumns`，列数不能超过限制。
5. 每行长度必须与第一行一致。
6. 每个字符必须属于 `_allowedLayoutSymbols`：`_`、空格、`#`、`B`、`T`、`*`。
7. 玩家坐标必须在布局内。
8. 玩家坐标必须是可通行地块。
9. 玩家不能和箱子重叠。
10. 至少一个箱子。
11. 至少一个目标点。
12. 箱子数量必须等于目标点数量。
13. 如果 `validateInitialDeadTiles` 为 true，开局非目标箱子不能在死格。
14. 如果 `requireSolvable` 为 true，且箱子数不超过 `maxBoxesForSolvability`，执行 `isSokobanStateSolvable`。

重要私有提取函数：

| 函数 | 作用 |
| --- | --- |
| `_levelFromPayload` | 从 JSON object 转成 `SokobanLevel` |
| `_requiredInt` | 必须是 `int` |
| `_requiredString` | 必须是 `String` |
| `_requiredStringList` | 必须是 `List<String>` |
| `_requiredMap` | 必须是 `Map<String, Object?>` |
| `_requiredDartInt` | 从 Dart 片段读 int |
| `_requiredDartString` | 从 Dart 片段读单引号字符串 |
| `_requiredDartListSource` | 从 Dart 片段截取 list 源码 |
| `_requiredDartBoardPosition` | 从 Dart 片段读 `BoardPosition(row, column)` |
| `_unescapeDartSingleQuotedString` | 处理 `\\`、`\'`、`\n`、`\r`、`\t` 等转义 |

### 9.4 CustomLevelStore

文件：`lib/src/levels/custom_level_store.dart`

`CustomLevelStore` 构造参数：

| 参数 | 类型 | 默认值 | 说明 |
| --- | --- | --- | --- |
| `storageFile` | `File?` | `_defaultStorageFile()` | 自定义关卡库文件 |
| `clock` | `DateTime Function()?` | `DateTime.now` | 生成 ID 和导入时间，测试可注入固定时间 |

#### loadCatalogItems

```dart
Future<List<LevelCatalogItem>> loadCatalogItems()
```

流程：

1. `_readRecordsAsync()` 读取存储记录。
2. 每条 `_CustomLevelRecord` 转成 `LevelCatalogItem`。
3. 返回列表。

#### importLevelJson

```dart
Future<LevelCatalogItem> importLevelJson(String source)
```

流程：

1. `trim()` 检查内容非空。
2. 用 UTF-8 计算字节数，超过 64 KB 拒绝。
3. 调用 `parseImportedSokobanLevelJsonAsync` 解析和校验。
4. 读取已有 record payloads。
5. 通过 `_createCustomLevelId` 生成唯一 ID。
6. 构造 `_CustomLevelRecord`。
7. 写入缩进 JSON。
8. 返回目录项。

#### 存储文件结构

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

#### 默认存储路径

`_defaultApplicationDataDirectory()` 根据平台选择：

| 平台 | 路径 |
| --- | --- |
| Windows | `%APPDATA%\Sokoban\custom_levels\custom_levels.json` |
| macOS | `$HOME/Library/Application Support/Sokoban/custom_levels.json` |
| Linux | `$XDG_DATA_HOME/Sokoban/custom_levels.json` 或 `$HOME/.local/share/Sokoban/custom_levels.json` |
| 其他 | 系统临时目录下的 `Sokoban/custom_levels.json` |

#### 关键私有函数

| 函数 | 作用 |
| --- | --- |
| `_readStorageSource` | 文件不存在或空文件时返回 `null` |
| `_writeRecordPayloadsAsync` | 创建父目录并写入格式化 JSON |
| `_sokobanLevelToJson` | 将 `SokobanLevel` 转为可保存对象 |
| `_createCustomLevelId` | 基于导入时间和序号生成不冲突 ID |
| `_recordsFromStorageSource` | 将存储 JSON 转成 `_CustomLevelRecord` |
| `_recordPayloadsFromStorageSource` | 校验根对象和 `levels` 列表 |
| `_encodeRecordPayloads` | 使用 `JsonEncoder.withIndent('  ')` 输出 |
| `_requiredString` | 校验存储记录字符串字段 |
| `_requiredDateTime` | 校验时间字段 |

## 10. Riverpod 状态管理

### 10.1 关卡目录控制器

文件：`lib/src/controllers/level_catalog_controller.dart`

Provider 列表：

| Provider | 类型 | 作用 |
| --- | --- | --- |
| `builtInLevelCatalogProvider` | `FutureProvider<List<LevelCatalogItem>>` | 异步加载内置关卡目录 |
| `customLevelStoreProvider` | `Provider<CustomLevelStore>` | 提供自定义关卡存储 |
| `levelCatalogControllerProvider` | `AsyncNotifierProvider<LevelCatalogController, LevelCatalogState>` | 管理自定义关卡列表与导入状态 |

#### LevelCatalogState

构造参数：

| 参数 | 类型 | 默认值 | 说明 |
| --- | --- | --- | --- |
| `customLevelCatalog` | `List<LevelCatalogItem>` | `const []` | 自定义关卡目录 |
| `isImporting` | `bool` | `false` | 是否正在导入 |

`copyWith` 可局部更新以上两个字段。

#### LevelCatalogController.build

```dart
Future<LevelCatalogState> build()
```

读取 `customLevelStoreProvider`，调用 `loadCatalogItems()`，将结果包装成不可变列表。

#### LevelCatalogController.importLevel

```dart
Future<LevelCatalogItem> importLevel(String input)
```

参数：

| 参数 | 类型 | 说明 |
| --- | --- | --- |
| `input` | `String` | 用户输入的 JSON 文本或文件路径 |

流程：

1. 取当前状态作为 `previousState`。
2. 设置 `isImporting: true`。
3. 用 `CustomLevelImportSourceReader.read(input)` 读取 JSON 源。
4. 用 `CustomLevelStore.importLevelJson(source)` 解析、保存。
5. 将新目录项追加到 `customLevelCatalog`。
6. 设置 `isImporting: false`。
7. 出错时恢复 `isImporting: false`，并保留原始 stack trace 重新抛出。

### 10.2 游戏控制器 Providers

文件：`lib/src/controllers/game_controller.dart`

| Provider | 类型 | 作用 |
| --- | --- | --- |
| `activeLevelCatalogProvider` | `Provider<List<LevelCatalogItem>>` | 合并内置关卡和自定义关卡 |
| `gameInitialLevelIndexProvider` | `Provider<int>` | 游戏页初始关卡索引，默认 0 |
| `gameControllerProvider` | `NotifierProvider.autoDispose<GameController, SokobanGameState>` | 游戏主状态控制器 |

`activeLevelCatalogProvider` 会读取：

- `builtInLevelCatalogProvider`
- `levelCatalogControllerProvider`

如果异步值还没 ready，就用空列表兜底。最后返回：

```dart
[...builtInCatalog, ...customCatalog]
```

`gameControllerProvider` 是 `autoDispose`，离开游戏页后会释放。

## 11. 游戏状态与控制器

### 11.1 GameMessageKind

```dart
enum GameMessageKind { status, deadlock, hint, completion }
```

| 值 | 说明 |
| --- | --- |
| `status` | 普通状态提示，比如关卡无效 |
| `deadlock` | 死局提示 |
| `hint` | 提示搜索结果 |
| `completion` | 过关 |

### 11.2 GameActionMessage

构造参数：

| 参数 | 类型 | 说明 |
| --- | --- | --- |
| `kind` | `GameMessageKind` | 消息类型 |
| `title` | `String` | 弹窗标题 |
| `message` | `String` | 弹窗正文 |

便捷构造：

| 构造 | 结果 |
| --- | --- |
| `GameActionMessage.status` | 自定义标题与正文 |
| `GameActionMessage.deadlock` | 标题固定为 `死局` |
| `GameActionMessage.hint` | 标题固定为 `提示` |
| `GameActionMessage.completion` | 标题 `过关`，正文 `全部箱子已到目标点，过关！` |

### 11.3 SokobanGameState

构造参数：

| 参数 | 类型 | 说明 |
| --- | --- | --- |
| `levelCatalog` | `List<LevelCatalogItem>` | 当前可玩关卡目录，构造时转不可变 |
| `currentLevelIndex` | `int` | 当前关卡索引 |
| `playerPosition` | `BoardPosition` | 玩家坐标 |
| `playerDirection` | `BoardPosition` | 玩家面向方向，主要用于绘制 |
| `brickPositions` | `Set<BoardPosition>` | 当前箱子坐标，构造时转不可变 |
| `targetPositions` | `Set<BoardPosition>` | 目标点坐标 |
| `deadTiles` | `Set<BoardPosition>` | 预计算死格 |
| `moveHistory` | `List<GameSnapshot>` | 撤销历史 |
| `stepCount` | `int` | 有效移动步数 |
| `levelValidationMessage` | `String?` | 加载时发现关卡无效的提示 |
| `deadlockMessage` | `String?` | 当前死局提示 |
| `hintedBrickPosition` | `BoardPosition?` | 高亮的箱子 |
| `hintDirection` | `BoardPosition?` | 提示推动方向 |
| `hintPushTargetPosition` | `BoardPosition?` | 箱子下一格高亮 |

#### SokobanGameState.load

```dart
factory SokobanGameState.load({
  required List<LevelCatalogItem> levelCatalog,
  required int levelIndex,
})
```

流程：

1. 断言 `levelCatalog` 非空。
2. 通过 `_normalisedLevelIndex` 把索引夹在合法范围内。
3. 读取当前关卡。
4. `positionsForSymbol(layout, 'B')` 得到箱子集合。
5. `positionsForSymbol(layout, 'T')` 得到目标点集合。
6. `computeDeadTiles` 计算死格。
7. 构造初始状态，玩家方向默认向下。
8. `_validateLoadedLevel` 做运行时关卡校验。
9. 如果关卡有效，调用 `_detectDeadlock` 检查开局死局。
10. 返回带校验消息或死局消息的状态。

#### 计算属性

| 属性 | 类型 | 说明 |
| --- | --- | --- |
| `currentLevel` | `SokobanLevel` | 当前目录项中的关卡 |
| `currentCatalogItem` | `LevelCatalogItem` | 当前目录项 |
| `currentLayout` | `List<String>` | 当前关卡布局 |
| `canUndo` | `bool` | `moveHistory.isNotEmpty` |
| `boxesOnTargetCount` | `int` | 箱子落在目标点上的数量 |
| `isLevelComplete` | `bool` | 目标非空且每个目标点都有箱子 |
| `visibleBoardPositions` | `Iterable<BoardPosition>` | 玩家、箱子、目标点、提示点合集 |
| `boardAspectRatio` | `double` | 当前可见棋盘比例 |

#### createSnapshot

返回当前玩家位置、箱子集合、步数的 `GameSnapshot`，用于移动前入栈。

#### copyWith

`copyWith` 支持修改所有状态字段。可空字段使用 `_unchanged` 哨兵对象区分：

- 不传：保留旧值。
- 显式传 `null`：清空字段。

这对 `levelValidationMessage`、`deadlockMessage`、提示相关坐标很重要。

#### clearActiveHint

返回一个清空提示高亮的新状态。

### 11.4 GameController

`GameController extends Notifier<SokobanGameState>`。

内部常量：

```dart
static const int _hintSolverMaxVisitedStates = 8000;
```

提示缓存：

| 字段 | 说明 |
| --- | --- |
| `_standardHintPathIndexes` | 内置关卡标准答案索引缓存，key 是 catalog item id |
| `_runtimeHintPathIndex` | 自定义或非标准路径搜索出来的临时解法索引 |
| `_runtimeHintPathLevelId` | 临时索引对应的关卡 ID |

#### build

```dart
SokobanGameState build()
```

流程：

1. 清理运行时提示缓存。
2. 读取 `activeLevelCatalogProvider`。
3. 读取 `gameInitialLevelIndexProvider`。
4. 调用 `SokobanGameState.load`。

注意：`SokobanGameState.load` 要求目录非空。游戏页外层 `_SokobanWallCatalogGate` 会在目录为空时显示加载页，避免直接构建游戏视图。

#### loadedLevelStatusMessage

返回当前已加载关卡的状态消息：

- 关卡无效：`status`
- 死局：`status`
- 已过关：`completion`
- 正常：`null`

#### resetCurrentLevel

重置当前关卡：

1. 清理运行时提示缓存。
2. 用当前 `levelCatalog` 和 `currentLevelIndex` 重新 `load`。
3. 返回加载状态消息。

#### changeLevel

```dart
GameActionMessage? changeLevel(int levelIndex)
```

如果索引越界或等于当前索引，返回 `null`。否则：

1. 清理提示缓存。
2. 加载新关卡。
3. 返回新关卡加载状态消息。

#### undoMove

撤销一步：

1. 如果 `canUndo` 为 false，直接返回。
2. 复制历史列表并弹出最后一个快照。
3. 用快照恢复玩家、箱子、步数。
4. 根据恢复后的箱子重新检测死局。
5. 清空当前提示高亮。

撤销不返回弹窗消息；UI 只是状态变化。

#### movePlayer

```dart
GameActionMessage? movePlayer(int rowOffset, int columnOffset)
```

参数：

| 参数 | 说明 |
| --- | --- |
| `rowOffset` | 行偏移 |
| `columnOffset` | 列偏移 |

核心规则：

1. 如果关卡本身无效，不移动。
2. 记录移动前 snapshot。
3. 计算玩家下一格 `nextPosition`。
4. 如果下一格有箱子：
   - 计算箱子下一格。
   - 箱子下一格必须是可行走地面，且没有箱子。
   - 无法推动时只更新玩家朝向，不计步。
   - 可以推动时更新箱子集合、玩家位置、朝向、历史、步数。
   - 推箱后检测死局。
   - 如果过关，返回 `completion`。
   - 如果死局，返回 `deadlock`。
5. 如果下一格没有箱子：
   - 下一格必须可行走。
   - 无法行走时只更新朝向，不计步。
   - 可以行走时更新玩家位置、朝向、历史、步数。

注意：当前实现把普通走动也计入步数，不只是推箱。

#### showHint

返回一个 `GameActionMessage`，同时可能更新棋盘高亮。

处理顺序：

1. 关卡无效：清空提示，返回关卡无效消息。
2. 已过关：清空提示，返回过关消息。
3. 已知死局：清空提示，返回死局消息。
4. 如果是内置关卡且有标准答案：
   - 尝试从标准答案索引查当前状态的下一推。
   - 找到则显示提示。
   - 找不到则尝试计算应撤销到哪一步。
5. 如果运行时缓存里有当前状态提示，直接使用。
6. 否则调用 `findNextSokobanPushHint` 搜索。
7. 根据搜索状态返回：
   - `alreadySolved`：过关。
   - `found`：缓存完整解法，显示第一步。
   - `noSolution`：提示当前局面无可通关路径。
   - `searchLimitReached`：提示局面复杂。

#### 标准答案路径恢复

当玩家偏离内置关卡标准答案时：

- `_standardPathRecovery` 从 `moveHistory` 倒序寻找仍能匹配标准答案的历史节点。
- 找到则提示撤销几步、回到第几步。
- 找不到则建议重置本关。

#### 重要私有函数

| 函数 | 作用 |
| --- | --- |
| `_normalisedLevelIndex` | 把关卡索引修正到合法范围 |
| `_loadedLevelStatusMessage` | 根据当前状态生成弹窗消息 |
| `_validateLoadedLevel` | 运行时关卡合法性检查 |
| `_detectDeadlock` | 检测当前箱子是否造成死局 |
| `_isWalkableFloor` | 判断某坐标是否可走且无箱子 |
| `_isInsideBoard` | 判断是否在当前 layout 内 |
| `_isBrickAt` | 判断是否有箱子 |
| `_formatPushHint` | 把 `SokobanPushHint` 格式化成中文提示 |
| `_formatBoardPosition` | 将 0 基坐标转成中文 1 基行列 |
| `_directionText` | 方向向量转 `上/下/左/右` |
| `_pushSideText` | 方向向量转玩家应站在箱子的哪一侧 |

## 12. 推箱子规则引擎

文件：`lib/src/game/sokoban_rules.dart`

这是项目最核心的领域逻辑文件。它不依赖 Flutter UI，只依赖模型。

### 12.1 基础常量与类型

`cardinalDirections`

```dart
const List<BoardPosition> cardinalDirections = [
  BoardPosition(row: -1, column: 0),
  BoardPosition(row: 1, column: 0),
  BoardPosition(row: 0, column: -1),
  BoardPosition(row: 0, column: 1),
];
```

表示上、下、左、右四个方向。

`SokobanSearchState`

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `playerPosition` | `BoardPosition` | 玩家位置 |
| `brickPositions` | `Set<BoardPosition>` | 箱子集合，构造时复制 |

`SokobanHintSearchStatus`

| 值 | 说明 |
| --- | --- |
| `alreadySolved` | 当前已经完成 |
| `found` | 找到解法 |
| `noSolution` | 确认无解或死局 |
| `searchLimitReached` | 达到搜索状态上限 |

`SokobanPushHint`

构造参数：

| 参数 | 类型 | 说明 |
| --- | --- | --- |
| `brickPosition` | `BoardPosition` | 被推动箱子的当前位置 |
| `direction` | `BoardPosition` | 推动方向 |

派生属性：

- `playerPushPosition`：玩家必须站的位置，即箱子反方向一格。
- `nextBrickPosition`：箱子被推后一格。

`SokobanHintSearchResult`

字段：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `status` | `SokobanHintSearchStatus` | 搜索状态 |
| `hint` | `SokobanPushHint?` | 下一步提示 |
| `solution` | `List<SokobanPushHint>` | 从当前状态到通关的推箱步骤 |

构造：

- `alreadySolved()`
- `found(hint, {solution})`
- `noSolution()`
- `searchLimitReached()`

### 12.2 基础棋盘函数

#### tileAt

```dart
BoardTile tileAt(List<String> layout, int row, int column)
```

返回指定坐标的地块类型。

注意：此函数不做越界保护，调用者必须先确保 row 和 column 合法。

映射：

- `_` -> `BoardTile.empty`
- `#` -> `BoardTile.wall`
- 其他 -> `BoardTile.floor`

#### positionsForSymbol

```dart
Set<BoardPosition> positionsForSymbol(List<String> layout, String symbol)
```

扫描布局中所有匹配某符号的位置。

特殊匹配：

- `symbol == 'B'` 时匹配 `B` 和 `*`。
- `symbol == 'T'` 时匹配 `T` 和 `*`。
- 其他符号精确匹配。

#### isInsideLayout

```dart
bool isInsideLayout(List<String> layout, BoardPosition position)
```

判断坐标是否在布局实际字符串边界内。

#### isFloorTile

```dart
bool isFloorTile(List<String> layout, BoardPosition position)
```

先判断是否在布局内，再判断 `tileAt` 是否为 `BoardTile.floor`。

#### isSolvedState

```dart
bool isSolvedState(
  Set<BoardPosition> brickPositions,
  Set<BoardPosition> targetPositions,
)
```

通关条件：

- 目标点非空。
- 箱子数等于目标点数。
- 每个箱子都在目标点集合里。

#### positionsKey

```dart
String positionsKey(Iterable<BoardPosition> positions)
```

将坐标集合排序后拼成稳定 key，例如：

```text
1,2;3,4
```

用于搜索去重。

#### searchStateKey

```dart
String searchStateKey(
  BoardPosition playerPosition,
  Set<BoardPosition> brickPositions,
)
```

格式：

```text
playerRow,playerColumn|boxRow,boxColumn;...
```

#### normalisedSearchStateKey

```dart
String normalisedSearchStateKey(
  List<String> layout,
  BoardPosition playerPosition,
  Set<BoardPosition> brickPositions,
)
```

它不是直接使用玩家当前坐标，而是先调用 `canonicalReachablePosition`。

这样做的目的：如果玩家在同一个连通区域内，不同站位对“箱子局面”通常等价。规范化后能减少搜索状态数量。

#### canonicalReachablePosition

```dart
BoardPosition canonicalReachablePosition(
  List<String> layout,
  BoardPosition playerPosition,
  Set<BoardPosition> brickPositions,
)
```

计算玩家在当前箱子阻挡下能到达的所有地面，然后选行最小、列最小的位置作为规范玩家位置。

如果没有可达地面，返回原玩家位置。

#### isValidSokobanPush

```dart
bool isValidSokobanPush({
  required List<String> layout,
  required BoardPosition playerPosition,
  required Set<BoardPosition> brickPositions,
  required SokobanPushHint push,
})
```

一个推箱提示有效的条件：

1. `push.brickPosition` 当前确实有箱子。
2. `push.nextBrickPosition` 是地板。
3. `push.nextBrickPosition` 当前没有箱子。
4. 玩家能走到 `push.playerPushPosition`。

#### applySokobanPush

```dart
Set<BoardPosition> applySokobanPush(
  Set<BoardPosition> brickPositions,
  SokobanPushHint push,
)
```

返回新的箱子集合：

- 移除旧箱子位置。
- 加入新箱子位置。

不会修改原集合。

### 12.3 死格计算

#### computeDeadTiles

```dart
Set<BoardPosition> computeDeadTiles(
  List<String> layout,
  Set<BoardPosition> targetPositions,
)
```

算法思想：反向推箱。

从所有目标点开始，反向寻找“一个箱子是否可能从某格被推到目标点”。如果某个地板格永远不能把箱子推到任何目标点，则是死格。

流程：

1. 把所有合法目标点加入 `reachablePositions` 和队列。
2. 从队列取当前位置 `currentPosition`。
3. 对每个方向，假设箱子是从 `previousBoxPosition` 被推到当前位置。
4. 玩家必须能站在 `playerSupportPosition` 才能完成这个推。
5. 两个位置都必须是地板。
6. 可反向到达的新箱子位置加入队列。
7. 最后扫描所有地板：
   - 不是目标点。
   - 不在反向可达集合，或是非目标角落死锁。
   - 则加入死格集合。

### 12.4 玩家可达区域

#### computeReachableFloors

```dart
Set<BoardPosition> computeReachableFloors(
  List<String> layout,
  BoardPosition startPosition,
  Set<BoardPosition> brickPositions,
)
```

用 BFS 计算玩家在当前箱子布局下可到达的地板集合。

阻挡条件：

- 非地板。
- 有箱子。
- 已访问过。

如果起点不是地板或起点有箱子，返回空集合。

### 12.5 死锁检测

#### formsFrozenSquareDeadlock

```dart
bool formsFrozenSquareDeadlock(
  List<String> layout,
  Set<BoardPosition> brickPositions,
  Set<BoardPosition> targetPositions,
  BoardPosition anchorPosition,
)
```

检测包含 `anchorPosition` 的四种可能 2x2 方块。

如果一个 2x2 方块中每格都是：

- 非地板，或
- 有箱子

并且至少有一个箱子不在目标点上，则形成 2x2 锁死块。

#### isNonTargetCornerDeadlock

```dart
bool isNonTargetCornerDeadlock(
  List<String> layout,
  Set<BoardPosition> targetPositions,
  BoardPosition position,
)
```

如果某位置不是目标点，且是地板，同时上下某侧被静态阻挡、左右某侧被静态阻挡，则箱子进入该角落无法移出。

静态阻挡包括：

- 越界。
- 非地板，例如墙或棋盘外。

#### hasSokobanDeadlock

```dart
bool hasSokobanDeadlock({
  required List<String> layout,
  required Set<BoardPosition> brickPositions,
  required Set<BoardPosition> targetPositions,
  required Set<BoardPosition> deadTiles,
  BoardPosition? movedBrickPosition,
})
```

综合死锁判断：

1. 已通关则不是死锁。
2. 任一非目标箱子在死格或非目标角落，死锁。
3. 如果传入 `movedBrickPosition`，只重点检查这个箱子附近的复杂死锁。
4. 否则检查所有箱子。
5. 检查 2x2 锁死块。
6. 检查冻结死锁。

#### formsFreezeDeadlock

```dart
bool formsFreezeDeadlock({
  required List<String> layout,
  required Set<BoardPosition> brickPositions,
  required Set<BoardPosition> targetPositions,
  required Set<BoardPosition> deadTiles,
  required BoardPosition anchorPosition,
})
```

冻结死锁用于检测一组相邻箱子被墙、死格或其他箱子互相卡住，导致某些非目标箱子再也不能移动。

流程：

1. `_freezeConnectedBoxes` 找到与 anchor 相邻连通的箱子组。
2. 跳过已经在目标点上的箱子。
3. 对每个非目标箱子，用 `_FreezeProbe.isFrozen` 判断横轴和纵轴是否都被阻塞。

`_FreezeProbe` 内部使用递归轴检查：

- 水平轴检查左右。
- 垂直轴检查上下。
- 如果遇到静态阻挡或死格，认为该方向阻塞。
- 如果遇到另一个箱子，递归检查另一个轴。
- `_axisChecks` 防止递归循环。

### 12.6 可解性搜索

#### isSokobanStateSolvable

```dart
bool isSokobanStateSolvable({
  required List<String> layout,
  required BoardPosition playerPosition,
  required Set<BoardPosition> brickPositions,
  required Set<BoardPosition> targetPositions,
  required Set<BoardPosition> deadTiles,
})
```

用途：

- 导入校验可选使用。
- 测试中用于验证关卡可解。

算法：

1. 已通关返回 `true`。
2. 当前死锁返回 `false`。
3. 创建 BFS 队列。
4. 用 `normalisedSearchStateKey` 去重。
5. 每轮：
   - 计算玩家可达地面。
   - 枚举所有箱子和四个方向。
   - 玩家必须能到箱子背后。
   - 箱子下一格必须是地板且无箱子。
   - 箱子不能被推到非目标死格。
   - 推后不能形成死锁。
   - 新状态没访问过则入队。
6. 队列耗尽仍未通关，则无解。

注意：这是完整搜索，没有显式最大状态上限；因此导入时默认 `requireSolvable` 为 false，并通过 `maxBoxesForSolvability` 限制复杂度。

### 12.7 下一步提示搜索

#### findNextSokobanPushHint

```dart
SokobanHintSearchResult findNextSokobanPushHint({
  required List<String> layout,
  required BoardPosition playerPosition,
  required Set<BoardPosition> brickPositions,
  required Set<BoardPosition> targetPositions,
  required Set<BoardPosition> deadTiles,
  int maxVisitedStates = 20000,
})
```

参数：

| 参数 | 默认值 | 说明 |
| --- | --- | --- |
| `layout` | 必填 | 棋盘布局 |
| `playerPosition` | 必填 | 当前玩家坐标 |
| `brickPositions` | 必填 | 当前箱子集合 |
| `targetPositions` | 必填 | 目标点集合 |
| `deadTiles` | 必填 | 死格集合 |
| `maxVisitedStates` | `20000` | 最大访问状态数；游戏页传 `8000` |

返回状态：

- 当前已解：`alreadySolved`
- 当前死锁：`noSolution`
- 上限小于等于 0：`searchLimitReached`
- 找到解法：`found`
- 搜索耗尽：`noSolution`
- 达到访问上限：`searchLimitReached`

算法不是普通 BFS，而是带启发式优先队列的搜索：

1. 初始节点 priority 为 `_solutionHeuristic`。
2. 使用自定义 `_PriorityQueue<_SokobanHintSearchNode>`。
3. 每个节点记录：
   - 玩家位置
   - 箱子集合
   - 推箱次数
   - priority
   - sequence
   - parent
   - lastPush
4. 每轮计算玩家可达区域。
5. 枚举所有可推动作。
6. 过滤非法动作、死格、死锁。
7. 用 `_solutionHeuristic` 对候选排序。
8. 发现通关时，通过 `_solutionForNode` 回溯完整推箱列表。

#### 启发式函数

`_solutionHeuristic`

主要由三部分构成：

1. 箱子到目标点的最小曼哈顿距离和，乘以 8。
2. 未在目标点上的箱子数量。
3. 对当前 push 的奖励或惩罚：
   - 推到目标点：减 5。
   - 从目标点推出：加 12。

`_minimumTargetDistanceSum`

用贪心方式把箱子匹配到最近目标点并累加距离，不是严格最优匹配，但速度快。

### 12.8 标准答案路径索引

`SokobanHintPathIndex.fromSolution`

参数：

| 参数 | 说明 |
| --- | --- |
| `layout` | 关卡布局 |
| `initialPlayerPosition` | 起始玩家位置 |
| `initialBrickPositions` | 起始箱子集合 |
| `solution` | 一串标准推箱动作 |

作用：

将完整解法转换成 `stateKey -> nextPush` 的 Map。

每一步都会调用 `isValidSokobanPush` 验证。如果标准答案在当前布局下不合法，返回空索引。

`hintForState`

参数：

- `layout`
- `playerPosition`
- `brickPositions`

先用规范化状态 key 查 Map，再验证该 push 在当前状态仍有效。

## 13. 游戏页面 UI

### 13.1 SokobanWallPage

文件：`lib/src/ui/sokoban_wall_page.dart`

构造参数：

| 参数 | 类型 | 默认值 | 说明 |
| --- | --- | --- | --- |
| `key` | `Key?` | 默认 | Widget key |
| `initialLevelIndex` | `int` | `0` | 初始关卡索引 |
| `levelCatalog` | `List<LevelCatalogItem>?` | `null` | 可选注入目录，测试或直接展示自定义关卡时使用 |

断言：

```dart
assert(levelCatalog == null || levelCatalog.length > 0)
```

实现特点：

- 每个 `SokobanWallPage` 内部再创建一个 `ProviderScope`。
- 使用 `gameInitialLevelIndexProvider.overrideWithValue(initialLevelIndex)` 注入初始索引。
- 如果传入 `levelCatalog`，则覆盖 `activeLevelCatalogProvider`。
- `scopeKey` 由初始索引和目录 ID 拼成，确保切换参数时重新构建状态。

### 13.2 _SokobanWallCatalogGate

当页面使用全局目录时，游戏目录可能还没加载完。该组件：

- 读取 `builtInLevelCatalogProvider`。
- 读取 `activeLevelCatalogProvider`。
- 如果 active catalog 非空，显示 `_SokobanWallView`。
- 如果内置加载失败，显示错误页面。
- 否则显示加载圆圈。

### 13.3 _SokobanWallViewState

这是游戏页主 UI 和交互入口。

生命周期：

- `initState` 中注册 `addPostFrameCallback`。
- 第一帧后调用 `loadedLevelStatusMessage`。
- 如果当前关卡开局无效、死局或已完成，立刻弹窗。

主要方法：

| 方法 | 作用 |
| --- | --- |
| `_showGameMessage` | 根据 `GameActionMessage` 类型弹出普通状态框或过关框 |
| `_showStatusDialog` | 通用 AlertDialog |
| `_showCompletionDialog` | 过关弹窗，提供留在本关和下一关/重玩 |
| `_movePlayer` | 调用 controller.movePlayer 并显示返回消息 |
| `_undoMove` | 调用 controller.undoMove |
| `_resetCurrentLevel` | 调用 controller.resetCurrentLevel |
| `_showHint` | 调用 controller.showHint |

键盘绑定：

| 键 | 行列偏移或动作 |
| --- | --- |
| ArrowUp / W | `(-1, 0)` |
| ArrowDown / S | `(1, 0)` |
| ArrowLeft / A | `(0, -1)` |
| ArrowRight / D | `(0, 1)` |
| Z | 撤销 |
| Ctrl+Z | 撤销 |

布局策略：

- 小屏幕 `shortestSide < 420` 时减少 padding。
- 棋盘区域使用 `Expanded + LayoutBuilder`。
- 可用棋盘高度 = 区域高度 - 头部高度 - 间距。
- 棋盘宽度 = `min(constraints.maxWidth, availableBoardHeight * boardAspectRatio)`。
- 棋盘高度 = `boardWidth / boardAspectRatio`。
- 头部宽度至少 220，但不超过父约束宽。

### 13.4 _BoardHeader

构造参数：

| 参数 | 类型 | 说明 |
| --- | --- | --- |
| `levelNumber` | `int` | 当前关卡编号 |
| `stepCount` | `int` | 当前步数 |

显示：

- `第 X 关`
- `步数 Y`

两段文字使用 `Flexible` 和 `TextOverflow.ellipsis` 防止窄屏溢出。

### 13.5 _HintControl

构造参数：

| 参数 | 类型 | 说明 |
| --- | --- | --- |
| `onHint` | `VoidCallback` | 点击提示按钮时执行 |

按钮：

- 宽度约束：160 到 240。
- 高度：48。
- 背景色：金色 `Color(0xFFD39C13)`。
- 图标：`LucideIcons.lightbulb`。

## 14. 关卡选择页 UI

文件：`lib/src/ui/level_selection_page.dart`

### 14.1 LevelSelectionPage

`LevelSelectionPage extends ConsumerWidget`。

它读取：

- `builtInLevelCatalogProvider`
- `levelCatalogControllerProvider`

并派生：

| 变量 | 说明 |
| --- | --- |
| `builtInLevelCatalog` | 已加载的内置目录，未 ready 时为空 |
| `isLoadingBuiltInLevels` | 内置目录初次加载中 |
| `builtInLevelLoadError` | 内置目录加载错误文案 |
| `customLevelCatalog` | 自定义目录 |
| `isLoadingCustomLevels` | 自定义目录初次加载中 |
| `customLevelLoadError` | 自定义目录加载错误文案 |
| `isImporting` | 是否正在导入 |

AppBar：

- 标题：`箱径`
- 右侧上传按钮：tooltip `导入关卡`
- 导入中时按钮 disabled

主体：

- 使用 `CustomScrollView` 和 slivers。
- 第一组：内置关卡。
- 第二组：自定义关卡。
- 根据屏幕宽度计算左右 padding、最大 grid 宽度和列数。

列数计算：

```dart
((gridWidth + 12) / (92 + 12)).floor()
```

保证每个关卡卡片 92x92，间距 12。

### 14.2 导入弹窗

`_showImportDialog(BuildContext context, WidgetRef ref)`

流程：

1. 打开 `_ImportLevelDialog`。
2. 用户取消则返回。
3. 调用 `levelCatalogControllerProvider.notifier.importLevel(input)`。
4. 成功：SnackBar 显示 `已导入：标题`。
5. 失败：SnackBar 显示 `导入失败：错误`。

`_ImportLevelDialog`

- StatefulWidget，内部持有 `TextEditingController`。
- AlertDialog 标题：`导入关卡`。
- TextField 支持 8 到 12 行。
- label：`JSON 内容或文件路径`。
- 操作按钮：取消、导入。

### 14.3 关卡分区组件

`_BuiltInLevelSection`

参数：

| 参数 | 类型 | 说明 |
| --- | --- | --- |
| `isLoading` | `bool` | 是否加载中 |
| `loadError` | `String?` | 错误文案 |
| `items` | `List<LevelCatalogItem>` | 内置关卡 |
| `gridDelegate` | `SliverGridDelegate` | 网格参数 |

显示优先级：

1. loading -> 72 高度加载圆圈。
2. error -> `_InlineMessage`。
3. empty -> `未找到生成关卡`。
4. 正常 -> `_LevelTileSliverGrid`。

`_CustomLevelSection` 同理，空态文案是 `还没有自定义关卡`。

### 14.4 _LevelTileSliverGrid

参数：

| 参数 | 说明 |
| --- | --- |
| `items` | 当前分区目录项 |
| `firstCatalogIndex` | 该分区第一项在合并目录中的索引 |
| `customOffset` | 展示编号偏移，当前传 0 |
| `gridDelegate` | 网格代理 |

点击卡片时：

```dart
context.pushNamed(
  AppRoute.level.name,
  pathParameters: {'index': '${firstCatalogIndex + index}'},
)
```

动画：

- 每 10 个 item 周期性延迟，`index % 10 * 16ms`。
- 淡入 180ms。
- 从 0.96 缩放到 1。

### 14.5 _LevelTile

参数：

| 参数 | 类型 | 说明 |
| --- | --- | --- |
| `catalogItem` | `LevelCatalogItem` | 目录项 |
| `displayIndex` | `int` | 显示序号 |
| `onTap` | `VoidCallback` | 点击动作 |

内置关卡显示：

- 中央大号编号。
- tooltip：`第 N 关 - 标题`。
- semantics label：`第 N 关`。

自定义关卡显示：

- 两行：`自定义` 和序号。
- tooltip：`自定义 X - 标题`。
- semantics label：`自定义关卡 X`。

### 14.6 _InlineMessage

显示内联状态，例如加载失败或空列表。

参数：

| 参数 | 类型 | 说明 |
| --- | --- | --- |
| `icon` | `IconData` | 图标 |
| `message` | `String` | 文案 |

## 15. 棋盘渲染

### 15.1 SokobanBoard

文件：`lib/src/ui/sokoban_board.dart`

构造参数：

| 参数 | 类型 | 默认值 | 说明 |
| --- | --- | --- | --- |
| `layout` | `List<String>` | 必填 | 布局矩阵 |
| `brickPositions` | `Set<BoardPosition>` | 必填 | 当前箱子 |
| `targetPositions` | `Set<BoardPosition>` | 必填 | 目标点 |
| `playerPosition` | `BoardPosition` | 必填 | 玩家 |
| `playerDirection` | `BoardPosition` | 向下 | 玩家朝向 |
| `hintedBrickPosition` | `BoardPosition?` | `null` | 提示箱子 |
| `hintDirection` | `BoardPosition?` | `null` | 提示方向 |
| `hintPushTargetPosition` | `BoardPosition?` | `null` | 提示下一格 |

静态方法：

- `viewportSizeForLayout`：返回 `BoardViewportSize`。
- `viewportRegionForLayout`：返回 `BoardViewportRegion`。

渲染流程：

1. 把玩家、箱子、目标点、提示点作为 `_visiblePositions`。
2. 计算可见 region。
3. 外层 Container 绘制棋盘背景、圆角、边框、阴影。
4. 用 `Column` 和 `Row` 按可见区域生成网格。
5. 每个单元格 Expanded 平均分布。
6. 如果坐标不在原 layout 中，渲染 `BoardTile.empty`。
7. 如果有箱子，tile 强制为 `BoardTile.brick`。
8. 否则用 `tileAt(layout, row, column)`。
9. 计算：
   - 是否目标点。
   - 是否提示箱子。
   - 是否提示下一格。
   - 是否玩家。
   - 墙边缘阴影信息。
10. 构造 `SokobanTile`。

`_wallEdgesForCell`

对非墙地面格检查上下左右是否邻接墙体，用于绘制靠墙的环境阴影。

`_isWallAt`

越界不是墙；只有 `tileAt == BoardTile.wall` 才算墙。

### 15.2 SokobanTile

文件：`lib/src/ui/sokoban_tile.dart`

构造参数：

| 参数 | 类型 | 默认值 | 说明 |
| --- | --- | --- | --- |
| `tile` | `BoardTile` | 必填 | 基础格类型 |
| `isTarget` | `bool` | 必填 | 是否目标点 |
| `hasPlayer` | `bool` | 必填 | 是否有玩家 |
| `visualRow` | `int` | `0` | 用于生成伪随机纹理 |
| `visualColumn` | `int` | `0` | 用于生成伪随机纹理 |
| `wallEdges` | `Set<SokobanTileEdge>` | 空集合 | 邻墙边 |
| `playerDirection` | `BoardPosition` | 向下 | 玩家朝向 |
| `isHintedBrick` | `bool` | `false` | 是否高亮箱子 |
| `isHintPushTarget` | `bool` | `false` | 是否高亮推后位置 |
| `hintDirection` | `BoardPosition?` | `null` | 箱子上绘制箭头 |

`SokobanTileEdge`

```dart
enum SokobanTileEdge { top, right, bottom, left }
```

渲染层级：

1. 地面、墙或空白底图 `_TileSurfacePainter`。
2. 目标点标记 `_TargetMarker`。
3. 提示目标格 `_HintPushTargetMarker`。
4. 箱子 `_CrateVisual`。
5. 箱子在目标点上的金色光圈 `_ActivatedGoalHalo`。
6. 提示箱子描边 `_HintedBrickOutline`。
7. 提示方向箭头 `_HintDirectionArrow`。
8. 玩家 `_PlayerAvatar`。

语义标签：

| 状态 | label |
| --- | --- |
| 空白 | `空白区域` |
| 墙 | `墙体` |
| 箱子在目标点 | `目标点上的箱子` |
| 箱子 | `箱子` |
| 玩家在目标点 | `人物所在的目标点` |
| 目标点 | `目标点` |
| 玩家在地面 | `人物所在位置` |
| 地面 | `地面` |

### 15.3 Tile 绘制器

`_TileSurfacePainter`

参数：

| 参数 | 说明 |
| --- | --- |
| `surface` | `_TileSurface.empty/floor/wall` |
| `seed` | 根据行列生成的视觉随机种子 |
| `wallEdges` | 邻接墙边 |

绘制函数：

| 函数 | 作用 |
| --- | --- |
| `_paintEmpty` | 棋盘外背景和少量颗粒 |
| `_paintFloor` | 地板渐变、软网格、颗粒、靠墙阴影 |
| `_paintWall` | 墙块渐变、阴影、高光、风化裂痕 |
| `_drawSoftGrid` | 地板细分线 |
| `_drawSparseGrain` | 随机颗粒 |
| `_drawWallAo` | 地面靠墙环境阴影 |
| `_drawWallWeathering` | 墙面磨损和裂纹 |

### 15.4 目标点、箱子、玩家和提示

| 组件 | 作用 |
| --- | --- |
| `_TargetMarker` / `_TargetMarkerPainter` | 绘制目标圆环和十字 |
| `_ActivatedGoalHalo` / `_ActivatedGoalHaloPainter` | 箱子到位时绘制金色光圈 |
| `_HintPushTargetMarker` / `_HintPushTargetPainter` | 绘制提示推后目标格 |
| `_CrateVisual` / `_CratePainter` | 绘制木箱和动画缩放 |
| `_HintedBrickOutline` | 高亮提示箱子边框 |
| `_HintDirectionArrow` | 根据方向显示 lucide 箭头 |
| `_PlayerAvatar` / `_PlayerPainter` | 绘制玩家形象和朝向 |

底层工具函数：

| 函数 | 作用 |
| --- | --- |
| `_floorTone` | 从地板色板中生成轻微变化色 |
| `_shiftHsl` | 调整颜色 HSL |
| `_clampUnit` | 将 double 限制到 0 到 1 |
| `_noise` | 基于 `sin` 的确定性伪随机数 |
| `_shortest` | 返回 `min(width, height)` |

## 16. 屏幕方向控制

文件：`lib/src/ui/movement_controls.dart`

`MovementControls`

构造参数：

| 参数 | 类型 | 说明 |
| --- | --- | --- |
| `onUp` | `VoidCallback` | 向上 |
| `onDown` | `VoidCallback` | 向下 |
| `onLeft` | `VoidCallback` | 向左 |
| `onRight` | `VoidCallback` | 向右 |

UI：

- 上、下、左、右四个 56x56 `FilledButton.tonal`。
- 中间是圆形玩家图标。
- 图标使用 `LucideIcons.chevron*`。
- 每个方向按钮有 Tooltip。

## 17. 关卡复制文案与预留列表

文件：`lib/src/levels/level_copy.dart`

`LevelCopy`

字段：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `title` | `String` | 关卡标题 |
| `description` | `String` | 关卡描述 |

`levelCopy` 是 40 条中文标题和描述。当前从 assets 加载关卡的代码没有直接引用它，可能是早期内置关卡方案遗留或供生成器/迁移使用。

文件：

- `lib/src/levels/intermediate_levels.dart`
- `lib/src/levels/advanced_levels.dart`

两者当前都是空列表：

```dart
final List<SokobanLevel> intermediateLevels = [];
final List<SokobanLevel> advancedLevels = [];
```

当前运行时也没有引用这两个列表。

## 18. 工具链

### 18.1 Dart 标准答案生成器

文件：`tool/generate_sokoban_standard_solutions.dart`

用途：读取 `tools/generated_levels` 中的关卡，调用 Dart 规则引擎的 `findNextSokobanPushHint`，生成 `tools/solution_levels/level_XXX.txt` 标准答案。

默认参数：

| 参数 | 默认值 | 说明 |
| --- | --- | --- |
| `--max-visited` | `250000` | 每关提示搜索最大访问状态 |
| `--output-dir` | `tools/solution_levels` | 输出目录 |
| `--level N` | 空 | 只处理指定关卡；可重复传 |
| `--check` | false | 只检查不写文件 |

主流程 `main(List<String> arguments)`：

1. 解析指定关卡号。
2. 解析最大搜索状态数。
3. 解析输出目录。
4. 判断是否写文件。
5. 遍历 `_loadGeneratedLevels()`。
6. 调用 `_solveLevel`。
7. 成功记录 solution，失败记录错误。
8. 非 check 模式写入答案文件。
9. 有失败关卡时设置 `exitCode = 1`。

重要函数：

| 函数 | 作用 |
| --- | --- |
| `_loadGeneratedLevels` | 从文件系统读取 generated levels |
| `_isGeneratedLevelFile` | 过滤 `.json` 和 `.dart.txt` |
| `_parseGeneratedLevelFile` | 解析 JSON 或 Dart 片段 |
| `_selectedLevelNumbers` | 解析多个 `--level` |
| `_intOption` | 解析整数选项 |
| `_stringOption` | 解析字符串选项 |
| `_solveLevel` | 调用 `findNextSokobanPushHint` |
| `_writeSolutionFiles` | 写入或清理并写入答案文件 |
| `_solutionFileName` | 格式化为 `level_001.txt` |
| `_renderSolutionFile` | 将推箱列表用分号拼接 |
| `_encodePush` | 编码 `row,column,direction` |
| `_encodeDirection` | 方向向量转 `U/D/L/R` |

### 18.2 Python 关卡编辑器

文件：`tools/sokoban_level_generator.py`

技术：Tkinter 桌面 GUI。

主要常量：

| 常量 | 值 | 说明 |
| --- | --- | --- |
| `CELL_SIZE` | `30` | 单元格像素 |
| `VISIBLE_BOARD_CELLS` | `20` | 可视网格数量 |
| `DEFAULT_ROWS` | `10` | 默认行数 |
| `DEFAULT_COLUMNS` | `15` | 默认列数 |
| `MAX_ROWS` | `40` | 最大行数 |
| `MAX_COLUMNS` | `40` | 最大列数 |
| `DEFAULT_SOLVER_TIME_LIMIT_SECONDS` | `60` | 求解超时 |
| `DEFAULT_EXPORT_DIR` | `tools/generated_levels` | 默认导出目录 |
| `DEFAULT_SOLUTION_DIR` | `tools/solution_levels` | 默认答案目录 |

工具模式：

| 工具 | 快捷键 | 符号 |
| --- | --- | --- |
| 墙体 | `1` | `#` |
| 地板 | `2` | 空格 |
| 棋盘外 | `3` | `_` |
| 人 | `4` | 不写入 layout，单独记录 |
| 箱子 | `5` | `B` 或 `*` |
| 目标点 | `6` | `T` 或 `*` |

顶层函数按职责分组：

| 函数 | 作用 |
| --- | --- |
| `next_export_level_number` | 扫描导出目录，返回下一个编号 |
| `_exported_level_numbers` | 收集已有文件中的编号 |
| `_level_number_from_file/json/text/filename` | 从文件内容或文件名推断编号 |
| `imported_level_payload_from_file` | 自动尝试 JSON、Dart、纯 Sokoban 文本导入 |
| `solution_text_for_level_payload` | 用 Python 求解器生成答案文本 |
| `solution_path_for_level_number` | 生成答案输出路径 |
| `write_solution_for_level_payload` | 写入标准答案 |
| `_solution_timeout_message` | 求解超时提示 |
| `_solution_failure_message` | 求解失败提示 |
| `_solution_complexity_reasons` | 解释复杂度原因 |
| `_level_complexity_summary` | 统计箱子、目标、地板、尺寸等 |
| `_solver_level_from_payload` | 转成 Python solver 输入 |
| `_import_payload_from_json_text` | JSON 导入 |
| `_import_payload_from_dart_text` | Dart 片段导入 |
| `_import_payload_from_plain_sokoban_text` | 纯文本 Sokoban 导入 |
| `_plain_sokoban_level_blocks` | 从文本中拆分关卡块 |
| `_plain_sokoban_layout_from_block` | 将文本块归一化为 layout |
| `_inline_player_position` | 从布局中找玩家符号 |
| `_coerce_import_payload` | 归一化导入 payload |
| `_coerce_level_number` | 清洗关卡编号 |
| `_coerce_player_position` | 清洗玩家坐标 |
| `_dart_string_field` | 从 Dart 片段取字符串字段 |
| `_iter_dart_string_literals` | 遍历 Dart 字符串字面量 |
| `_unescape_dart_string` | 处理转义 |

`SokobanLevelGenerator(tk.Tk)` 主要方法：

| 方法 | 作用 |
| --- | --- |
| `__init__` | 初始化窗口、状态、网格 |
| `_build_ui` | 构建工具栏、画布、表单、按钮 |
| `_bind_shortcuts` | 绑定快捷键 |
| `_handle_level_number_change` | 编号变化时同步标题 |
| `_current_level_number` | 读取当前编号 |
| `_sync_level_title` | 自动同步标题 |
| `_refresh_auto_level_number` | 刷新下一个编号 |
| `_create_grid` | 创建矩阵 |
| `_draw_grid` | 绘制整张网格 |
| `_redraw_cell` | 重绘单格 |
| `_rebuild_grid` | 按输入行列重建 |
| `_clear_to_floor` | 清空为地板 |
| `_add_border_walls` | 添加外框墙 |
| `_paint_from_event` | 鼠标绘制 |
| `_erase_from_event` | 鼠标擦除 |
| `_event_to_cell` | 鼠标坐标转行列 |
| `_apply_tool` | 应用当前工具 |
| `_place_player` | 放置玩家 |
| `_place_box` | 放置箱子，处理目标点上的箱子 |
| `_place_target` | 放置目标点，处理箱子上的目标点 |
| `_set_plain_cell` | 设置普通格 |
| `_count_symbols` | 统计符号数量 |
| `_layout_rows` | 获取当前 layout |
| `_import_level` | 打开文件并导入 |
| `_load_imported_level` | 将 payload 放入编辑器状态 |
| `_normalized_import_grid` | 归一化导入矩阵 |
| `_import_symbol_for_char` | 导入字符映射 |
| `_import_edit_warnings` | 生成导入警告 |
| `_level_payload` | 组装导出 payload |
| `_dart_snippet` | 生成 Dart 片段 |
| `_export_json` | 导出 JSON |
| `_export_dart` | 导出 Dart 片段 |
| `_safe_int` | 安全解析整数 |
| `_escape_dart_string` | Dart 字符串转义 |

### 18.3 Python 求解器

文件：`tools/sokoban_level_solver.py`

用途：为生成器和离线工具提供更完整的求解能力。

核心类型：

| 类型 | 说明 |
| --- | --- |
| `Move` | 上下左右，携带行列偏移和编码字符 |
| `BoardPosition` | 冻结 dataclass 坐标 |
| `SokobanSolveTimeout` | 求解超时异常 |
| `SokobanLevel` | layout 和玩家初始位置 |
| `SolverState` | 搜索状态，包含玩家、箱子、父节点、走路片段 |
| `SokobanPush` | 一次推箱动作 |
| `_QueueNode` | 优先队列节点 |
| `SokobanSolver` | 求解器 |
| `_FreezeProbe` | 冻结死锁递归检测 |

`SokobanSolver` 主要方法：

| 方法 | 作用 |
| --- | --- |
| `__init__` | 解析地图、目标、箱子、死格、距离表 |
| `_parse_map` | 扫描地板、目标、箱子 |
| `solve` | 返回完整移动序列 `list[Move]` |
| `solve_pushes` | 返回推箱序列 `list[SokobanPush]` |
| `_check_search_limits` | 检查超时或状态上限 |
| `heuristic` | 计算搜索启发式 |
| `_base_heuristic` | 缓存基础启发式 |
| `_minimum_target_distance_sum` | 估算箱子到目标距离 |
| `_minimum_target_distance_matching` | 小箱子数量时做更精确匹配 |
| `_nearest_target_push_distance` | 最近目标推动距离 |
| `_target_push_distance` | 目标距离查表 |
| `_is_solved` | 判断是否通关 |
| `_normalized_state_key` | 状态规范化 key |
| `_compute_reachable_map` | 玩家可达区域和路径父信息 |
| `_reconstruct_walk` | 回溯走路片段 |
| `_reconstruct_solution` | 回溯完整 Move 解 |
| `_reconstruct_push_solution` | 回溯推箱解 |
| `_compute_target_distances` | 计算每个目标的反向推动距离 |
| `_compute_pull_distances_from_target` | 单目标反向距离 |
| `_compute_dead_tiles` | 死格集合 |
| `_has_deadlock` | 综合死锁 |
| `_forms_frozen_square_deadlock` | 2x2 死锁 |
| `_forms_freeze_deadlock` | 冻结死锁 |
| `_freeze_connected_boxes` | 找连通箱子 |
| `_is_corner_deadlock` | 角落死锁 |
| `_is_static_blocker` | 静态阻挡 |
| `_is_floor_tile` | 是否地板 |
| `_is_inside_layout` | 是否在布局内 |

顶层函数：

- `format_moves(moves)`：将移动序列转成 `UDLR` 字符串。
- `format_pushes(pushes)`：将推箱序列转成 `row,column,direction` 格式。
- `main()`：CLI 入口。

### 18.4 图标生成脚本

文件：`tools/generate_app_icons.ps1`

技术：

- PowerShell
- `System.Drawing`
- 手工绘制位图、缩放 PNG、写 ICO

主要函数：

| 函数 | 作用 |
| --- | --- |
| `New-Color` | HEX 转 `System.Drawing.Color` |
| `New-RoundedPath` | 创建圆角矩形路径 |
| `Fill-RoundedRect` | 填充圆角矩形 |
| `Draw-RoundedRect` | 绘制圆角矩形边框 |
| `New-AppIconBitmap` | 绘制 1024 主图标 |
| `Resize-Bitmap` | 缩放位图 |
| `Save-Png` | 保存 PNG |
| `Get-PngBytes` | 获取 PNG 字节 |
| `Save-Ico` | 写 Windows ICO |

输出：

- Android mipmap：`ic_launcher.png`
- Windows：`windows/runner/resources/app_icon.ico`
- 文档预览：`docs/app_logo.png`

## 19. 平台配置

### 19.1 Android

主要文件：

- `android/app/build.gradle.kts`
- `android/app/src/main/AndroidManifest.xml`
- `android/app/src/main/res/values/strings.xml`

配置要点：

- `namespace = "com.example.app"`
- `applicationId = "com.example.app"`，仍是模板 ID，发布前应改成真实唯一 ID。
- Java/Kotlin 目标版本为 17。
- release 当前使用 debug signing config，仅适合开发或临时运行。
- App label 来自 `@string/app_name`，值为 `箱径`。
- 启动图标是 `@mipmap/ic_launcher`。

### 19.2 Windows

主要文件：

- `windows/CMakeLists.txt`
- `windows/runner/main.cpp`

配置要点：

- CMake project 名：`boxtrail`
- 可执行文件名：`boxtrail`
- 窗口标题：`箱径`
- 默认窗口大小：1280x720
- C++ 标准：C++17

## 20. 测试覆盖

### 20.1 widget_test.dart

覆盖：

- generated levels 基础结构合法。
- 关卡按编号排序。
- 棋盘 viewport 根据可见区域计算。
- 生成关卡可包装成内置目录。
- 关卡选择页可渲染。
- 点击内置关卡进入游戏页。
- 自定义关卡仍在加载时也能打开内置关卡。
- 宽关卡可渲染所有可见格。
- 粘贴 JSON 导入自定义关卡并打开。

测试辅助：

- `_MemoryLevelStore`：内存实现的 `CustomLevelStore`。
- `_PendingLevelStore`：永不完成加载，用于测试异步加载场景。
- `_pumpUntilFound`：最多 pump 20 次等待 widget 出现。

### 20.2 sokoban_level_import_test.dart

覆盖：

- JSON 解析。
- Dart 片段解析。
- 空标题回退为 `自定义关卡`。
- 非法 JSON。
- 缺字段。
- 非矩形布局。
- 非法字符。
- 箱子目标数量不一致。
- 玩家在墙上。
- 玩家和箱子重叠。
- 尺寸限制。
- 大于旧固定棋盘尺寸的关卡默认可接受。
- `*` 同时作为箱子和目标点。

### 20.3 custom_level_store_test.dart

覆盖：

- 导入自定义关卡并重新加载。
- ID 以导入时间开头。
- source 为 `LevelSource.custom`。
- 无效 JSON 不写入存储文件。

### 20.4 sokoban_hint_test.dart

覆盖：

- `findNextSokobanPushHint` 返回通关第一推。
- 死局初始状态返回无解。
- 标准答案文本解析。
- 内置标准提示偏离路径时提示撤销。
- 提示按钮直接显示下一推。

### 20.5 level_catalog_test.dart

覆盖：

- generated levels 包装成 built-in catalog。
- `SokobanWallPage` 使用注入目录。
- `initialLevelIndex` 改变时页面重新加载。

## 21. 关键业务流程

### 21.1 启动到关卡选择

```text
main
  -> SokobanApp
    -> ProviderScope
      -> _SokobanMaterialApp
        -> appRouterProvider
          -> LevelSelectionPage
```

`LevelSelectionPage` 同时触发：

- `builtInLevelCatalogProvider` 读取内置关卡。
- `levelCatalogControllerProvider` 读取自定义关卡。

### 21.2 进入游戏页

```text
LevelTile.onTap
  -> context.pushNamed('level', index)
    -> GoRouter /level/:index
      -> SokobanWallPage(initialLevelIndex: index)
        -> ProviderScope override initial index
          -> _SokobanWallCatalogGate
            -> _SokobanWallView
              -> gameControllerProvider
                -> SokobanGameState.load
```

### 21.3 移动一步

```text
键盘或方向按钮
  -> _movePlayer(rowOffset, columnOffset)
    -> GameController.movePlayer
      -> 计算下一格
      -> 可走或可推则更新状态
      -> 检测过关或死局
    -> UI 根据返回消息弹窗
```

### 21.4 撤销

```text
撤销按钮 / Z / Ctrl+Z
  -> _undoMove
    -> GameController.undoMove
      -> pop GameSnapshot
      -> 恢复玩家、箱子、步数
      -> 清空提示
```

### 21.5 提示

```text
提示按钮
  -> GameController.showHint
    -> 检查无效/完成/死局
    -> 内置标准答案索引
    -> 运行时缓存
    -> findNextSokobanPushHint 搜索
    -> 设置 hintedBrickPosition / hintDirection / hintPushTargetPosition
    -> 弹窗显示中文提示
```

### 21.6 导入自定义关卡

```text
关卡选择页上传按钮
  -> _ImportLevelDialog
    -> LevelCatalogController.importLevel(input)
      -> CustomLevelImportSourceReader.read(input)
        -> JSON 文本或文件内容
      -> CustomLevelStore.importLevelJson(source)
        -> parseImportedSokobanLevelJsonAsync
        -> validateImportedSokobanLevel
        -> 写 custom_levels.json
      -> 更新 customLevelCatalog
    -> SnackBar 反馈
```

## 22. 设计取舍与注意点

### 22.1 状态不可变

`SokobanGameState` 构造时会把列表和集合转为不可变副本。控制器更新状态时创建新集合和新状态，符合 Riverpod 的响应式模型。

### 22.2 玩家位置规范化

搜索状态使用 `normalisedSearchStateKey`，把玩家在同一连通区域内的不同位置视作等价。这显著减少搜索状态数量，是推箱子求解中很关键的优化。

### 22.3 普通移动也计步

`movePlayer` 中只要玩家成功移动，无论是否推箱，都增加 `stepCount`。如果后续产品希望只统计推箱次数，需要新增字段或改变计数语义。

### 22.4 关卡加载和游戏页的异步保护

游戏控制器要求目录非空。`SokobanWallPage` 在未注入目录时会先经过 `_SokobanWallCatalogGate`，目录为空则显示加载或错误页面，不直接构建游戏视图。

### 22.5 标准答案与运行时搜索并存

内置关卡优先使用标准答案，速度快且路线稳定。自定义关卡或偏离标准答案的状态会使用运行时搜索。运行时搜索结果会缓存为 `SokobanHintPathIndex`，后续连续点击提示时不用重复搜完整路径。

### 22.6 自定义关卡默认不要求完整可解性

`parseImportedSokobanLevelJson` 默认会检查结构、数量、坐标和初始死格，但不会执行完整可解性搜索。这样导入响应更快，避免复杂关卡卡住 UI。需要时可通过 `SokobanLevelValidationOptions(requireSolvable: true)` 开启。

### 22.7 assets 与文件系统两套加载路径

运行时 Flutter App 从 `AssetBundle` 读取 generated levels 和 solution levels。Dart CLI 工具从文件系统读取同一批目录。两套路径职责不同：

- App：`AssetManifest + rootBundle`
- CLI：`Directory('tools/generated_levels')`

## 23. 常用命令

安装依赖：

```powershell
flutter pub get
```

运行 Windows：

```powershell
flutter run -d windows
```

运行 Android：

```powershell
flutter run -d android
```

测试：

```powershell
flutter test
```

静态分析：

```powershell
dart analyze
```

生成标准答案：

```powershell
dart run tool\generate_sokoban_standard_solutions.dart
```

只检查某一关：

```powershell
dart run tool\generate_sokoban_standard_solutions.dart --level 12 --check
```

打开 Python 关卡编辑器：

```powershell
python tools\sokoban_level_generator.py
```

生成 App 图标：

```powershell
.\tools\generate_app_icons.ps1
```

## 24. 后续维护建议

1. 清理或更新 `README.md` 中关于 `introductory_levels.dart` 的旧描述，避免和当前 assets 加载架构冲突。
2. 如果发布 Android，应修改 `applicationId = "com.example.app"` 和 release 签名配置。
3. 如果保留 `shared_preferences` 依赖，应明确用途；否则可以删除未使用依赖。
4. 自定义关卡当前只支持导入和加载，后续可补删除、重命名、导出。
5. 如果关卡数量继续增加，建议为 generated levels 和 standard solutions 增加一致性检查，例如每个内置关卡都应有对应标准答案。
6. 如果开启导入时完整可解性验证，应加入超时或 isolate，避免 UI 线程卡顿。

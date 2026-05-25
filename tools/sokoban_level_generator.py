import json
import re
import tkinter as tk
from pathlib import Path
from tkinter import filedialog, messagebox, ttk

try:
    from sokoban_level_solver import (
        BoardPosition as SolverBoardPosition,
        format_pushes,
        SokobanLevel as SolverLevel,
        SokobanSolveTimeout,
        SokobanSolver,
    )
except ImportError:
    from .sokoban_level_solver import (
        BoardPosition as SolverBoardPosition,
        format_pushes,
        SokobanLevel as SolverLevel,
        SokobanSolveTimeout,
        SokobanSolver,
    )


CELL_SIZE = 30
BOARD_LABEL_MARGIN = 28
VISIBLE_BOARD_CELLS = 20
BOARD_VIEW_SIZE = BOARD_LABEL_MARGIN + VISIBLE_BOARD_CELLS * CELL_SIZE
DEFAULT_ROWS = 10
DEFAULT_COLUMNS = 15
MAX_ROWS = 40
MAX_COLUMNS = 40
DEFAULT_SOLVER_TIME_LIMIT_SECONDS = 60

PROJECT_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_EXPORT_DIR = PROJECT_ROOT / "tools" / "generated_levels"
DEFAULT_SOLUTION_DIR = PROJECT_ROOT / "tools" / "solution_levels"
LEVEL_NUMBER_PATTERN = re.compile(r"\bnumber\s*:\s*(\d+)\b")
LEVEL_FILENAME_PATTERN = re.compile(r"level[_-]?(\d+)", re.IGNORECASE)
DART_STRING_LITERAL_PATTERN = re.compile(
    r"'((?:\\.|[^'\\])*)'|\"((?:\\.|[^\"\\])*)\""
)
DART_LAYOUT_PATTERN = re.compile(r"\blayout\s*:\s*\[(.*?)\]", re.DOTALL)
DART_PLAYER_PATTERN = re.compile(
    r"\binitialPlayerPosition\s*:\s*BoardPosition\s*\(\s*"
    r"row\s*:\s*(-?\d+)\s*,\s*column\s*:\s*(-?\d+)\s*\)",
    re.DOTALL,
)

SYMBOLS = {
    "outside": "_",
    "floor": " ",
    "wall": "#",
    "box": "B",
    "target": "T",
    "box_target": "*",
}

IMPORT_SYMBOLS = {
    "_": (SYMBOLS["outside"], False),
    " ": (SYMBOLS["floor"], False),
    "#": (SYMBOLS["wall"], False),
    "B": (SYMBOLS["box"], False),
    "$": (SYMBOLS["box"], False),
    "T": (SYMBOLS["target"], False),
    ".": (SYMBOLS["target"], False),
    "*": (SYMBOLS["box_target"], False),
    "P": (SYMBOLS["floor"], True),
    "p": (SYMBOLS["floor"], True),
    "@": (SYMBOLS["floor"], True),
    "+": (SYMBOLS["target"], True),
}

TOOL_LABELS = {
    "wall": "墙体",
    "floor": "地板",
    "outside": "棋盘外",
    "player": "人",
    "box": "箱子",
    "target": "目标点",
}

TOOL_KEYS = {
    "wall": "1",
    "floor": "2",
    "outside": "3",
    "player": "4",
    "box": "5",
    "target": "6",
}

CELL_COLORS = {
    "_": "#e5e7eb",
    " ": "#f8fafc",
    "#": "#334155",
    "B": "#b45309",
    "T": "#60a5fa",
    "*": "#22c55e",
}

TEXT_COLORS = {
    "_": "#64748b",
    " ": "#94a3b8",
    "#": "#f8fafc",
    "B": "#fff7ed",
    "T": "#0f172a",
    "*": "#052e16",
}


def next_export_level_number(export_dir=DEFAULT_EXPORT_DIR):
    return min(max(_exported_level_numbers(export_dir), default=0) + 1, 999)


def _exported_level_numbers(export_dir):
    if not export_dir.exists():
        return []

    numbers = []
    for path in export_dir.iterdir():
        if not path.is_file():
            continue

        number = _level_number_from_file(path)
        if number is not None:
            numbers.append(number)

    return numbers


def _level_number_from_file(path):
    if path.suffix.lower() == ".json":
        number = _level_number_from_json(path)
        if number is not None:
            return number

    number = _level_number_from_text(path)
    if number is not None:
        return number

    match = LEVEL_FILENAME_PATTERN.search(path.stem)
    if match:
        return int(match.group(1))

    return None


def _level_number_from_json(path):
    try:
        with open(path, "r", encoding="utf-8") as file:
            payload = json.load(file)
    except (OSError, json.JSONDecodeError):
        return None

    number = payload.get("number") if isinstance(payload, dict) else None
    return number if isinstance(number, int) and number >= 1 else None


def _level_number_from_text(path):
    try:
        text = path.read_text(encoding="utf-8", errors="ignore")
    except OSError:
        return None

    match = LEVEL_NUMBER_PATTERN.search(text)
    return int(match.group(1)) if match else None


def imported_level_payload_from_file(path):
    path = Path(path)
    try:
        source = path.read_text(encoding="utf-8")
    except OSError as error:
        raise ValueError(f"无法读取文件：{error}") from error

    parse_errors = []
    looks_like_json = path.suffix.lower() == ".json" or source.lstrip().startswith("{")
    if looks_like_json:
        try:
            return _import_payload_from_json_text(source, path)
        except ValueError as error:
            if path.suffix.lower() == ".json":
                raise
            parse_errors.append(str(error))

    try:
        return _import_payload_from_dart_text(source, path)
    except ValueError as error:
        if parse_errors:
            raise ValueError(f"{parse_errors[0]}\n{error}") from error
        raise


def solution_text_for_level_payload(
    payload,
    max_seconds=DEFAULT_SOLVER_TIME_LIMIT_SECONDS,
):
    solver_level = _solver_level_from_payload(payload)
    solver = SokobanSolver(solver_level)
    try:
        pushes = solver.solve_pushes(max_seconds=max_seconds)
    except SokobanSolveTimeout as error:
        raise ValueError(str(error)) from error

    if pushes is None:
        raise ValueError("未找到可通关解决方案，已取消导出。")

    return format_pushes(pushes)


def solution_path_for_level_number(level_number):
    return DEFAULT_SOLUTION_DIR / f"level_{level_number:03}.txt"


def write_solution_for_level_payload(payload, solution_text=None):
    if solution_text is None:
        solution_text = solution_text_for_level_payload(payload)

    DEFAULT_SOLUTION_DIR.mkdir(parents=True, exist_ok=True)
    solution_path = solution_path_for_level_number(payload["number"])
    solution_path.write_text(
        f"{solution_text}\n" if solution_text else "",
        encoding="utf-8",
    )
    return solution_path


def _solver_level_from_payload(payload):
    player_position = payload["initialPlayerPosition"]
    return SolverLevel(
        layout=tuple(payload["layout"]),
        initial_player_position=SolverBoardPosition(
            row=player_position["row"],
            column=player_position["column"],
        ),
    )


def _import_payload_from_json_text(source, path):
    try:
        payload = json.loads(source)
    except json.JSONDecodeError as error:
        raise ValueError(f"JSON 无法解析：{error}") from error

    return _coerce_import_payload(
        payload,
        fallback_number=_level_number_from_filename(path),
    )


def _import_payload_from_dart_text(source, path):
    number_match = LEVEL_NUMBER_PATTERN.search(source)
    number = int(number_match.group(1)) if number_match else None

    layout_match = DART_LAYOUT_PATTERN.search(source)
    if layout_match is None:
        raise ValueError("未找到 Dart layout 列表。")

    layout = list(_iter_dart_string_literals(layout_match.group(1)))
    if not layout:
        raise ValueError("Dart layout 列表为空。")

    player_match = DART_PLAYER_PATTERN.search(source)
    player_position = None
    if player_match:
        player_position = {
            "row": int(player_match.group(1)),
            "column": int(player_match.group(2)),
        }

    return _coerce_import_payload(
        {
            "number": number,
            "title": _dart_string_field(source, "title"),
            "description": _dart_string_field(source, "description"),
            "layout": layout,
            "initialPlayerPosition": player_position,
        },
        fallback_number=_level_number_from_filename(path),
    )


def _coerce_import_payload(payload, fallback_number=None):
    if not isinstance(payload, dict):
        raise ValueError("关卡根节点必须是对象。")

    layout_value = payload.get("layout")
    if not isinstance(layout_value, list):
        raise ValueError("缺少 layout，或 layout 不是字符串列表。")

    layout = []
    for index, row in enumerate(layout_value):
        if not isinstance(row, str):
            raise ValueError(f"layout 第 {index + 1} 行不是字符串。")
        layout.append(row)

    number = _coerce_level_number(payload.get("number"), fallback_number)
    title = payload.get("title")
    description = payload.get("description")

    return {
        "number": number,
        "title": title.strip() if isinstance(title, str) and title.strip() else None,
        "description": description.strip() if isinstance(description, str) else "",
        "layout": layout,
        "initialPlayerPosition": _coerce_player_position(
            payload.get("initialPlayerPosition")
        ),
    }


def _coerce_level_number(value, fallback_number):
    if isinstance(value, int):
        return value
    if isinstance(value, str) and value.strip().isdigit():
        return int(value.strip())
    if isinstance(fallback_number, int):
        return fallback_number
    return 1


def _coerce_player_position(value):
    if not isinstance(value, dict):
        return None

    row = value.get("row")
    column = value.get("column")
    if not isinstance(row, int) or not isinstance(column, int):
        return None

    return {"row": row, "column": column}


def _level_number_from_filename(path):
    match = LEVEL_FILENAME_PATTERN.search(Path(path).stem)
    return int(match.group(1)) if match else None


def _dart_string_field(source, field):
    match = re.search(
        rf"\b{re.escape(field)}\s*:\s*(?:'((?:\\.|[^'\\])*)'|\"((?:\\.|[^\"\\])*)\")",
        source,
        re.DOTALL,
    )
    return _dart_string_literal_value(match) if match else None


def _iter_dart_string_literals(source):
    for match in DART_STRING_LITERAL_PATTERN.finditer(source):
        yield _dart_string_literal_value(match)


def _dart_string_literal_value(match):
    escaped = match.group(1) if match.group(1) is not None else match.group(2)
    return _unescape_dart_string(escaped)


def _unescape_dart_string(value):
    result = []
    escaping = False
    escapes = {
        "n": "\n",
        "r": "\r",
        "t": "\t",
        "\\": "\\",
        "'": "'",
        '"': '"',
    }

    for char in value:
        if escaping:
            result.append(escapes.get(char, char))
            escaping = False
        elif char == "\\":
            escaping = True
        else:
            result.append(char)

    if escaping:
        result.append("\\")

    return "".join(result)


class SokobanLevelGenerator(tk.Tk):
    def __init__(self):
        super().__init__()

        self.title("推箱子关卡生成器")
        self.geometry("980x760")
        self.minsize(760, 560)

        self.rows_var = tk.IntVar(value=DEFAULT_ROWS)
        self.columns_var = tk.IntVar(value=DEFAULT_COLUMNS)
        DEFAULT_EXPORT_DIR.mkdir(parents=True, exist_ok=True)
        self._auto_level_number = next_export_level_number()
        self._level_number_is_custom = False
        self._updating_level_number = False
        self.level_number_var = tk.IntVar(value=self._auto_level_number)
        self.level_title_var = tk.StringVar(
            value=self._level_title_for_number(self._auto_level_number)
        )
        self.description_var = tk.StringVar(value="把箱子推到目标点。")
        self.tool_var = tk.StringVar(value="wall")
        self.status_var = tk.StringVar(
            value=f"选择工具后点击格子开始设计。默认导出目录：{DEFAULT_EXPORT_DIR}"
        )

        self.grid_data = []
        self.player_position = None
        self.rectangles = {}
        self.labels = {}

        self._build_ui()
        self._create_grid(DEFAULT_ROWS, DEFAULT_COLUMNS)
        self._bind_shortcuts()
        self.level_number_var.trace_add("write", self._handle_level_number_change)

    def _build_ui(self):
        root = ttk.Frame(self, padding=12)
        root.pack(fill=tk.BOTH, expand=True)
        root.columnconfigure(0, weight=0)
        root.columnconfigure(1, weight=1)
        root.rowconfigure(0, weight=1)

        sidebar = ttk.Frame(root)
        sidebar.grid(row=0, column=0, sticky="nsw", padx=(0, 12))
        sidebar.columnconfigure(0, weight=1)

        settings = ttk.LabelFrame(sidebar, text="关卡信息", padding=10)
        settings.grid(row=0, column=0, sticky="ew")
        settings.columnconfigure(1, weight=1)

        ttk.Label(settings, text="关卡号").grid(row=0, column=0, sticky="w")
        ttk.Spinbox(
            settings,
            from_=1,
            to=999,
            textvariable=self.level_number_var,
            width=7,
        ).grid(row=0, column=1, sticky="ew", padx=(8, 0))

        ttk.Label(settings, text="标题").grid(
            row=1,
            column=0,
            sticky="w",
            pady=(8, 0),
        )
        ttk.Label(settings, textvariable=self.level_title_var, anchor="w").grid(
            row=1,
            column=1,
            sticky="ew",
            padx=(8, 0),
            pady=(8, 0),
        )

        ttk.Label(settings, text="描述").grid(
            row=2,
            column=0,
            sticky="w",
            pady=(8, 0),
        )
        ttk.Entry(settings, textvariable=self.description_var, width=28).grid(
            row=2,
            column=1,
            sticky="ew",
            padx=(8, 0),
            pady=(8, 0),
        )

        matrix = ttk.LabelFrame(sidebar, text="矩阵", padding=10)
        matrix.grid(row=1, column=0, sticky="ew", pady=(10, 0))
        matrix.columnconfigure(1, weight=1)

        ttk.Label(matrix, text="行").grid(row=0, column=0, sticky="w")
        ttk.Spinbox(
            matrix,
            from_=3,
            to=MAX_ROWS,
            textvariable=self.rows_var,
            width=5,
        ).grid(row=0, column=1, sticky="ew", padx=(8, 0))

        ttk.Label(matrix, text="列").grid(row=1, column=0, sticky="w", pady=(8, 0))
        ttk.Spinbox(
            matrix,
            from_=3,
            to=MAX_COLUMNS,
            textvariable=self.columns_var,
            width=5,
        ).grid(row=1, column=1, sticky="ew", padx=(8, 0), pady=(8, 0))

        ttk.Button(matrix, text="重建矩阵", command=self._rebuild_grid).grid(
            row=2,
            column=0,
            columnspan=2,
            sticky="ew",
            pady=(6, 0),
        )
        ttk.Button(matrix, text="清空为地板", command=self._clear_to_floor).grid(
            row=3,
            column=0,
            columnspan=2,
            sticky="ew",
            pady=(8, 0),
        )
        ttk.Button(matrix, text="生成外框墙", command=self._add_border_walls).grid(
            row=4,
            column=0,
            columnspan=2,
            sticky="ew",
            pady=(8, 0),
        )

        tools = ttk.LabelFrame(sidebar, text="工具", padding=10)
        tools.grid(row=2, column=0, sticky="ew", pady=(10, 0))
        tools.columnconfigure(0, weight=1)

        for index, tool in enumerate(TOOL_LABELS):
            label = f"{TOOL_KEYS[tool]} {TOOL_LABELS[tool]}"
            ttk.Radiobutton(
                tools,
                text=label,
                variable=self.tool_var,
                value=tool,
            ).grid(row=index, column=0, sticky="w", pady=(0, 6))

        export = ttk.LabelFrame(sidebar, text="导入/导出", padding=10)
        export.grid(row=3, column=0, sticky="ew", pady=(10, 0))
        export.columnconfigure(0, weight=1)

        ttk.Button(export, text="导入 JSON/Dart", command=self._import_level).grid(
            row=0,
            column=0,
            sticky="ew",
        )
        ttk.Button(export, text="导出 Dart 片段", command=self._export_dart).grid(
            row=1,
            column=0,
            sticky="ew",
            pady=(8, 0),
        )
        ttk.Button(export, text="导出 JSON", command=self._export_json).grid(
            row=2,
            column=0,
            sticky="ew",
            pady=(8, 0),
        )

        board_frame = ttk.LabelFrame(root, text="编辑区", padding=10)
        board_frame.grid(row=0, column=1, sticky="nsew")
        board_frame.rowconfigure(0, weight=1)
        board_frame.columnconfigure(0, weight=1)

        self.canvas = tk.Canvas(
            board_frame,
            background="#ffffff",
            highlightthickness=1,
            highlightbackground="#cbd5e1",
            width=BOARD_VIEW_SIZE,
            height=BOARD_VIEW_SIZE,
        )
        y_scrollbar = ttk.Scrollbar(
            board_frame,
            orient=tk.VERTICAL,
            command=self.canvas.yview,
        )
        x_scrollbar = ttk.Scrollbar(
            board_frame,
            orient=tk.HORIZONTAL,
            command=self.canvas.xview,
        )
        self.canvas.configure(
            xscrollcommand=x_scrollbar.set,
            yscrollcommand=y_scrollbar.set,
        )

        self.canvas.grid(row=0, column=0, sticky="nsew")
        y_scrollbar.grid(row=0, column=1, sticky="ns")
        x_scrollbar.grid(row=1, column=0, sticky="ew")

        self.canvas.bind("<Button-1>", self._paint_from_event)
        self.canvas.bind("<B1-Motion>", self._paint_from_event)
        self.canvas.bind("<Button-3>", self._erase_from_event)

        status = ttk.Label(root, textvariable=self.status_var, anchor="w")
        status.grid(row=1, column=0, columnspan=2, sticky="ew", pady=(8, 0))

    def _bind_shortcuts(self):
        for tool, key in TOOL_KEYS.items():
            self.bind(key, lambda _event, selected=tool: self.tool_var.set(selected))
        self.bind("<Control-s>", lambda _event: self._export_dart())
        self.bind("<Control-o>", lambda _event: self._import_level())

    def _handle_level_number_change(self, *_args):
        self._sync_level_title()
        if self._updating_level_number:
            return

        self._level_number_is_custom = True

    @staticmethod
    def _level_title_for_number(number):
        return "第{0}关".format(number)

    def _current_level_number(self):
        try:
            value = self.level_number_var.get()
        except tk.TclError:
            value = self._auto_level_number

        return self._safe_int(value, self._auto_level_number, 1, 999)

    def _sync_level_title(self):
        self.level_title_var.set(
            self._level_title_for_number(self._current_level_number())
        )

    def _refresh_auto_level_number(self):
        if self._level_number_is_custom:
            return

        self._set_auto_level_number(next_export_level_number())

    def _set_auto_level_number(self, number):
        self._auto_level_number = number
        self._updating_level_number = True
        try:
            self.level_number_var.set(number)
        finally:
            self._updating_level_number = False
        self._sync_level_title()

    def _create_grid(self, rows, columns):
        self.grid_data = [[SYMBOLS["floor"] for _ in range(columns)] for _ in range(rows)]
        self.player_position = None
        self._draw_grid()

    def _draw_grid(self):
        self.canvas.delete("all")
        self.rectangles.clear()
        self.labels.clear()

        rows = len(self.grid_data)
        columns = len(self.grid_data[0]) if rows else 0
        width = columns * CELL_SIZE
        height = rows * CELL_SIZE
        self.canvas.configure(
            scrollregion=(-BOARD_LABEL_MARGIN, -BOARD_LABEL_MARGIN, width, height)
        )
        self.canvas.xview_moveto(0)
        self.canvas.yview_moveto(0)

        for column in range(columns):
            self.canvas.create_text(
                column * CELL_SIZE + CELL_SIZE / 2,
                -BOARD_LABEL_MARGIN / 2,
                text=str(column),
                fill="#475569",
                font=("Segoe UI", 9, "bold"),
            )

        for row in range(rows):
            self.canvas.create_text(
                -BOARD_LABEL_MARGIN / 2,
                row * CELL_SIZE + CELL_SIZE / 2,
                text=str(row),
                fill="#475569",
                font=("Segoe UI", 9, "bold"),
            )

        for row in range(rows):
            for column in range(columns):
                x0 = column * CELL_SIZE
                y0 = row * CELL_SIZE
                x1 = x0 + CELL_SIZE
                y1 = y0 + CELL_SIZE
                rect = self.canvas.create_rectangle(
                    x0,
                    y0,
                    x1,
                    y1,
                    fill="#ffffff",
                    outline="#cbd5e1",
                )
                label = self.canvas.create_text(
                    x0 + CELL_SIZE / 2,
                    y0 + CELL_SIZE / 2,
                    text="",
                    fill="#0f172a",
                    font=("Segoe UI", 12, "bold"),
                )
                self.rectangles[(row, column)] = rect
                self.labels[(row, column)] = label
                self._redraw_cell(row, column)

    def _redraw_cell(self, row, column):
        symbol = self.grid_data[row][column]
        fill = CELL_COLORS[symbol]
        text = "" if symbol == " " else symbol
        text_color = TEXT_COLORS[symbol]

        if self.player_position == (row, column):
            fill = "#fef08a"
            text = "P" if symbol == " " else f"P/{symbol}"
            text_color = "#713f12"

        self.canvas.itemconfigure(self.rectangles[(row, column)], fill=fill)
        self.canvas.itemconfigure(
            self.labels[(row, column)],
            text=text,
            fill=text_color,
        )

    def _redraw_all_cells(self):
        for row in range(len(self.grid_data)):
            for column in range(len(self.grid_data[row])):
                self._redraw_cell(row, column)

    def _rebuild_grid(self):
        rows = self._safe_int(self.rows_var.get(), DEFAULT_ROWS, 3, MAX_ROWS)
        columns = self._safe_int(
            self.columns_var.get(),
            DEFAULT_COLUMNS,
            3,
            MAX_COLUMNS,
        )
        self.rows_var.set(rows)
        self.columns_var.set(columns)
        self._create_grid(rows, columns)
        self.status_var.set(f"已重建 {rows} x {columns} 矩阵。")

    def _clear_to_floor(self):
        rows = len(self.grid_data)
        columns = len(self.grid_data[0])
        self.grid_data = [[SYMBOLS["floor"] for _ in range(columns)] for _ in range(rows)]
        self.player_position = None
        self._redraw_all_cells()
        self.status_var.set("已清空为地板。")

    def _add_border_walls(self):
        rows = len(self.grid_data)
        columns = len(self.grid_data[0])
        for row in range(rows):
            for column in range(columns):
                if row in (0, rows - 1) or column in (0, columns - 1):
                    self.grid_data[row][column] = SYMBOLS["wall"]
                    if self.player_position == (row, column):
                        self.player_position = None
        self._redraw_all_cells()
        self.status_var.set("已生成外框墙。")

    def _paint_from_event(self, event):
        cell = self._event_to_cell(event)
        if cell is None:
            return

        row, column = cell
        self._apply_tool(row, column, self.tool_var.get())

    def _erase_from_event(self, event):
        cell = self._event_to_cell(event)
        if cell is None:
            return

        row, column = cell
        self._apply_tool(row, column, "floor")

    def _event_to_cell(self, event):
        x = self.canvas.canvasx(event.x)
        y = self.canvas.canvasy(event.y)
        column = int(x // CELL_SIZE)
        row = int(y // CELL_SIZE)

        if row < 0 or column < 0:
            return None
        if row >= len(self.grid_data) or column >= len(self.grid_data[0]):
            return None

        return row, column

    def _apply_tool(self, row, column, tool):
        previous_player_position = self.player_position

        if tool == "player":
            self._place_player(row, column)
        elif tool == "box":
            self._place_box(row, column)
        elif tool == "target":
            self._place_target(row, column)
        elif tool == "wall":
            self._set_plain_cell(row, column, SYMBOLS["wall"])
        elif tool == "outside":
            self._set_plain_cell(row, column, SYMBOLS["outside"])
        else:
            self._set_plain_cell(row, column, SYMBOLS["floor"])

        self._redraw_cell(row, column)
        if previous_player_position and previous_player_position != self.player_position:
            previous_row, previous_column = previous_player_position
            self._redraw_cell(previous_row, previous_column)

    def _place_player(self, row, column):
        symbol = self.grid_data[row][column]
        if symbol in (SYMBOLS["box"], SYMBOLS["box_target"]):
            self.status_var.set("玩家不能放在箱子上。")
            return

        if symbol in (SYMBOLS["outside"], SYMBOLS["wall"]):
            self.grid_data[row][column] = SYMBOLS["floor"]

        old_position = self.player_position
        self.player_position = (row, column)
        if old_position and old_position != self.player_position:
            self._redraw_cell(*old_position)
        self.status_var.set(f"已设置玩家位置：row {row}, column {column}。")

    def _place_box(self, row, column):
        if self.player_position == (row, column):
            self.status_var.set("箱子不能和玩家重叠。")
            return

        current = self.grid_data[row][column]
        self.grid_data[row][column] = (
            SYMBOLS["box_target"]
            if current in (SYMBOLS["target"], SYMBOLS["box_target"])
            else SYMBOLS["box"]
        )
        box_count = self._count_symbols(SYMBOLS["box"], SYMBOLS["box_target"])
        self.status_var.set(
            f"已设置箱子：row {row}, column {column}。当前箱子数：{box_count}。"
        )

    def _place_target(self, row, column):
        current = self.grid_data[row][column]
        if current in (SYMBOLS["box"], SYMBOLS["box_target"]):
            new_target_symbol = SYMBOLS["box_target"]
        elif current in (SYMBOLS["wall"], SYMBOLS["outside"]):
            new_target_symbol = SYMBOLS["target"]
        else:
            new_target_symbol = SYMBOLS["target"]

        self.grid_data[row][column] = new_target_symbol
        target_count = self._count_symbols(SYMBOLS["target"], SYMBOLS["box_target"])
        self.status_var.set(
            f"已设置目标点：row {row}, column {column}。当前目标点数：{target_count}。"
        )

    def _set_plain_cell(self, row, column, symbol):
        self.grid_data[row][column] = symbol
        if self.player_position == (row, column) and symbol in (
            SYMBOLS["wall"],
            SYMBOLS["outside"],
        ):
            self.player_position = None
        self.status_var.set(f"已设置 {TOOL_LABELS[self.tool_var.get()]}。")

    def _count_symbols(self, *symbols):
        return sum(
            1
            for row in self.grid_data
            for value in row
            if value in symbols
        )

    def _layout_rows(self):
        return ["".join(row) for row in self.grid_data]

    def _import_level(self):
        path = filedialog.askopenfilename(
            title="导入关卡",
            initialdir=str(DEFAULT_EXPORT_DIR),
            filetypes=[
                ("关卡文件", "*.json *.txt *.dart"),
                ("JSON", "*.json"),
                ("Dart/文本", "*.dart *.txt"),
                ("所有文件", "*.*"),
            ],
        )
        if not path:
            return

        import_path = Path(path)
        try:
            payload = imported_level_payload_from_file(import_path)
            warnings = self._load_imported_level(payload)
        except ValueError as error:
            messagebox.showerror("无法导入", str(error))
            return

        rows = len(self.grid_data)
        columns = len(self.grid_data[0]) if rows else 0
        if warnings:
            self.status_var.set(
                f"已导入 {import_path.name}（{rows} x {columns}）。"
                f"发现 {len(warnings)} 个需要修改的提示。"
            )
            messagebox.showwarning(
                "已导入，存在需要修改的地方",
                self._warning_message(warnings),
            )
            return

        self.status_var.set(f"已导入 {import_path.name}（{rows} x {columns}）。")
        messagebox.showinfo("导入完成", f"已导入关卡：\n{import_path}")

    def _load_imported_level(self, payload):
        grid_data, player_position, warnings = self._normalized_import_grid(
            payload["layout"],
            payload["initialPlayerPosition"],
        )

        rows = len(grid_data)
        columns = len(grid_data[0]) if rows else 0
        level_number = self._safe_int(
            payload["number"],
            self._auto_level_number,
            1,
            999,
        )

        self.rows_var.set(rows)
        self.columns_var.set(columns)
        self.description_var.set(payload["description"])
        self.level_number_var.set(level_number)
        self._level_number_is_custom = True
        self._sync_level_title()

        self.grid_data = grid_data
        self.player_position = player_position
        self._draw_grid()

        warnings.extend(self._import_edit_warnings())
        return warnings

    def _normalized_import_grid(self, layout, payload_player_position):
        if not layout:
            raise ValueError("layout 不能为空。")

        rows = len(layout)
        columns = max(len(row) for row in layout)
        if columns == 0:
            raise ValueError("layout 的行不能为空字符串。")
        if rows > MAX_ROWS:
            raise ValueError(f"当前关卡行数为 {rows}，最多支持 {MAX_ROWS} 行。")
        if columns > MAX_COLUMNS:
            raise ValueError(f"当前关卡列数为 {columns}，最多支持 {MAX_COLUMNS} 列。")

        warnings = []
        if any(len(row) != columns for row in layout):
            warnings.append("layout 行长度不一致，短行已用地板补齐。")

        grid_data = []
        inline_player_position = None
        extra_inline_players = 0
        for row_index, row_text in enumerate(layout):
            cells = []
            for column_index in range(columns):
                char = (
                    row_text[column_index]
                    if column_index < len(row_text)
                    else SYMBOLS["floor"]
                )
                symbol, has_player = self._import_symbol_for_char(
                    char,
                    row_index,
                    column_index,
                )
                if has_player:
                    if inline_player_position is None:
                        inline_player_position = (row_index, column_index)
                    else:
                        extra_inline_players += 1
                cells.append(symbol)
            grid_data.append(cells)

        if extra_inline_players:
            warnings.append("layout 中存在多个玩家符号，仅保留第一个。")

        player_position = inline_player_position
        if payload_player_position is not None:
            imported_position = (
                payload_player_position["row"],
                payload_player_position["column"],
            )
            if self._position_inside_grid(imported_position, rows, columns):
                if inline_player_position and inline_player_position != imported_position:
                    warnings.append(
                        "layout 中的玩家符号与 initialPlayerPosition 不一致，"
                        "已使用 initialPlayerPosition。"
                    )
                player_position = imported_position
            elif inline_player_position:
                warnings.append(
                    "initialPlayerPosition 越界，已使用 layout 中的玩家符号。"
                )
            else:
                warnings.append("initialPlayerPosition 越界，已清空玩家位置。")

        return grid_data, player_position, warnings

    def _import_symbol_for_char(self, char, row, column):
        if char not in IMPORT_SYMBOLS:
            raise ValueError(
                f"layout 第 {row + 1} 行第 {column + 1} 列存在非法字符 `{char}`。"
            )

        return IMPORT_SYMBOLS[char]

    @staticmethod
    def _position_inside_grid(position, rows, columns):
        row, column = position
        return 0 <= row < rows and 0 <= column < columns

    def _import_edit_warnings(self):
        warnings = []
        if self.player_position is None:
            warnings.append("未找到玩家位置，导出前请放置玩家。")
        else:
            player_row, player_column = self.player_position
            player_symbol = self.grid_data[player_row][player_column]
            if player_symbol in (SYMBOLS["wall"], SYMBOLS["outside"]):
                warnings.append("玩家初始位置位于墙体或棋盘外，导出前需要修正。")
            elif player_symbol in (SYMBOLS["box"], SYMBOLS["box_target"]):
                warnings.append("玩家初始位置和箱子重叠，导出前需要修正。")

        box_count = self._count_symbols(SYMBOLS["box"], SYMBOLS["box_target"])
        target_count = self._count_symbols(SYMBOLS["target"], SYMBOLS["box_target"])
        if box_count < 1:
            warnings.append("关卡至少需要一个箱子。")
        if target_count < 1:
            warnings.append("关卡至少需要一个目标点。")
        if box_count != target_count:
            warnings.append(
                f"箱子数量必须与目标点数量一致。当前箱子 {box_count} 个，"
                f"目标点 {target_count} 个。"
            )

        return warnings

    @staticmethod
    def _warning_message(warnings):
        visible_warnings = warnings[:8]
        message = "\n".join(f"- {warning}" for warning in visible_warnings)
        if len(warnings) > len(visible_warnings):
            message += f"\n- 另有 {len(warnings) - len(visible_warnings)} 个提示。"
        return message

    def _level_payload(self):
        self._refresh_auto_level_number()

        if self.player_position is None:
            raise ValueError("请先放置玩家。")

        player_row, player_column = self.player_position
        player_symbol = self.grid_data[player_row][player_column]
        if player_symbol in (
            SYMBOLS["wall"],
            SYMBOLS["outside"],
            SYMBOLS["box"],
            SYMBOLS["box_target"],
        ):
            raise ValueError("玩家必须放在地板或目标点上。")

        box_count = self._count_symbols(SYMBOLS["box"], SYMBOLS["box_target"])
        target_count = self._count_symbols(SYMBOLS["target"], SYMBOLS["box_target"])
        if box_count < 1:
            raise ValueError("每个关卡至少需要一个箱子。")
        if target_count < 1:
            raise ValueError("每个关卡至少需要一个目标点。")
        if box_count != target_count:
            raise ValueError(
                f"箱子数量必须与目标点数量一致。当前箱子 {box_count} 个，"
                f"目标点 {target_count} 个。"
            )

        level_number = self._current_level_number()
        title = self._level_title_for_number(level_number)
        self.level_title_var.set(title)

        return {
            "number": level_number,
            "title": title,
            "description": self.description_var.get().strip(),
            "layout": self._layout_rows(),
            "initialPlayerPosition": {
                "row": player_row,
                "column": player_column,
            },
        }

    def _dart_snippet(self, payload):
        rows = "\n".join(
            f"      '{self._escape_dart_string(row)}',"
            for row in payload["layout"]
        )
        title = self._escape_dart_string(payload["title"])
        description = self._escape_dart_string(payload["description"])
        player = payload["initialPlayerPosition"]

        return (
            "  SokobanLevel(\n"
            f"    number: {payload['number']},\n"
            f"    title: '{title}',\n"
            f"    description: '{description}',\n"
            "    layout: [\n"
            f"{rows}\n"
            "    ],\n"
            "    initialPlayerPosition: "
            f"BoardPosition(row: {player['row']}, column: {player['column']}),\n"
            "  ),\n"
        )

    def _export_json(self):
        try:
            payload = self._level_payload()
        except ValueError as error:
            messagebox.showerror("无法导出", str(error))
            return

        DEFAULT_EXPORT_DIR.mkdir(parents=True, exist_ok=True)
        default_name = f"level_{payload['number']:03}.json"
        path = filedialog.asksaveasfilename(
            title="导出 JSON",
            initialdir=str(DEFAULT_EXPORT_DIR),
            initialfile=default_name,
            defaultextension=".json",
            filetypes=[("JSON", "*.json"), ("所有文件", "*.*")],
        )
        if not path:
            return

        try:
            self.status_var.set("正在生成解决方案...")
            self.update_idletasks()
            solution_text = solution_text_for_level_payload(payload)
        except ValueError as error:
            messagebox.showerror("无法导出", str(error))
            self.status_var.set(str(error))
            return

        try:
            with open(path, "w", encoding="utf-8") as file:
                json.dump(payload, file, ensure_ascii=False, indent=2)
                file.write("\n")
            solution_path = write_solution_for_level_payload(
                payload,
                solution_text=solution_text,
            )
        except OSError as error:
            messagebox.showerror("无法导出", f"无法写入文件：{error}")
            self.status_var.set(f"无法写入文件：{error}")
            return

        self.status_var.set(f"已导出 JSON：{path}；解决方案：{solution_path}")
        self._refresh_auto_level_number()
        messagebox.showinfo(
            "导出完成",
            f"已导出 JSON：\n{path}\n\n已生成解决方案：\n{solution_path}",
        )

    def _export_dart(self):
        try:
            payload = self._level_payload()
        except ValueError as error:
            messagebox.showerror("无法导出", str(error))
            return

        DEFAULT_EXPORT_DIR.mkdir(parents=True, exist_ok=True)
        default_name = f"level_{payload['number']:03}.dart.txt"
        path = filedialog.asksaveasfilename(
            title="导出 Dart 片段",
            initialdir=str(DEFAULT_EXPORT_DIR),
            initialfile=default_name,
            defaultextension=".txt",
            filetypes=[("文本文件", "*.txt"), ("Dart 文件", "*.dart"), ("所有文件", "*.*")],
        )
        if not path:
            return

        try:
            self.status_var.set("正在生成解决方案...")
            self.update_idletasks()
            solution_text = solution_text_for_level_payload(payload)
        except ValueError as error:
            messagebox.showerror("无法导出", str(error))
            self.status_var.set(str(error))
            return

        snippet = self._dart_snippet(payload)
        try:
            with open(path, "w", encoding="utf-8") as file:
                file.write(snippet)
            solution_path = write_solution_for_level_payload(
                payload,
                solution_text=solution_text,
            )
        except OSError as error:
            messagebox.showerror("无法导出", f"无法写入文件：{error}")
            self.status_var.set(f"无法写入文件：{error}")
            return

        self.clipboard_clear()
        self.clipboard_append(snippet)
        self.status_var.set(
            f"已导出 Dart 片段并复制到剪贴板：{path}；解决方案：{solution_path}"
        )
        self._refresh_auto_level_number()
        messagebox.showinfo(
            "导出完成",
            f"已导出 Dart 片段，并复制到剪贴板：\n{path}\n\n"
            f"已生成解决方案：\n{solution_path}",
        )

    @staticmethod
    def _safe_int(value, default, minimum, maximum):
        try:
            parsed = int(value)
        except (TypeError, ValueError):
            parsed = default

        return max(minimum, min(maximum, parsed))

    @staticmethod
    def _escape_dart_string(value):
        return value.replace("\\", "\\\\").replace("'", "\\'")


if __name__ == "__main__":
    app = SokobanLevelGenerator()
    app.mainloop()

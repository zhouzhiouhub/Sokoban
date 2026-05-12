import json
import re
import tkinter as tk
from pathlib import Path
from tkinter import filedialog, messagebox, ttk


CELL_SIZE = 34
DEFAULT_ROWS = 10
DEFAULT_COLUMNS = 15
MAX_ROWS = 40
MAX_COLUMNS = 40

PROJECT_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_EXPORT_DIR = PROJECT_ROOT / "tools" / "generated_levels"
LEVEL_NUMBER_PATTERN = re.compile(r"\bnumber\s*:\s*(\d+)\b")
LEVEL_FILENAME_PATTERN = re.compile(r"level[_-]?(\d+)", re.IGNORECASE)

SYMBOLS = {
    "outside": "_",
    "floor": " ",
    "wall": "#",
    "box": "B",
    "target": "T",
    "box_target": "*",
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
        self.level_title_var = tk.StringVar(value="自定义关卡")
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
        self.level_number_var.trace_add("write", self._mark_level_number_custom)

    def _build_ui(self):
        root = ttk.Frame(self, padding=12)
        root.pack(fill=tk.BOTH, expand=True)
        root.columnconfigure(0, weight=1)
        root.rowconfigure(2, weight=1)

        settings = ttk.LabelFrame(root, text="关卡信息", padding=10)
        settings.grid(row=0, column=0, sticky="ew")
        for index in range(8):
            settings.columnconfigure(index, weight=1)

        ttk.Label(settings, text="行").grid(row=0, column=0, sticky="w")
        ttk.Spinbox(
            settings,
            from_=3,
            to=MAX_ROWS,
            textvariable=self.rows_var,
            width=5,
        ).grid(row=0, column=1, sticky="w")

        ttk.Label(settings, text="列").grid(row=0, column=2, sticky="w")
        ttk.Spinbox(
            settings,
            from_=3,
            to=MAX_COLUMNS,
            textvariable=self.columns_var,
            width=5,
        ).grid(row=0, column=3, sticky="w")

        ttk.Button(settings, text="重建矩阵", command=self._rebuild_grid).grid(
            row=0,
            column=4,
            sticky="w",
            padx=(8, 0),
        )
        ttk.Button(settings, text="清空为地板", command=self._clear_to_floor).grid(
            row=0,
            column=5,
            sticky="w",
            padx=(8, 0),
        )
        ttk.Button(settings, text="生成外框墙", command=self._add_border_walls).grid(
            row=0,
            column=6,
            sticky="w",
            padx=(8, 0),
        )

        ttk.Label(settings, text="关卡号").grid(
            row=1,
            column=0,
            sticky="w",
            pady=(8, 0),
        )
        ttk.Spinbox(
            settings,
            from_=1,
            to=999,
            textvariable=self.level_number_var,
            width=7,
        ).grid(row=1, column=1, sticky="w", pady=(8, 0))

        ttk.Label(settings, text="标题").grid(
            row=1,
            column=2,
            sticky="w",
            pady=(8, 0),
        )
        ttk.Entry(settings, textvariable=self.level_title_var, width=20).grid(
            row=1,
            column=3,
            columnspan=2,
            sticky="ew",
            pady=(8, 0),
        )

        ttk.Label(settings, text="描述").grid(
            row=1,
            column=5,
            sticky="w",
            pady=(8, 0),
        )
        ttk.Entry(settings, textvariable=self.description_var, width=42).grid(
            row=1,
            column=6,
            columnspan=2,
            sticky="ew",
            pady=(8, 0),
        )

        tools = ttk.LabelFrame(root, text="工具", padding=10)
        tools.grid(row=1, column=0, sticky="ew", pady=(10, 0))

        for index, tool in enumerate(TOOL_LABELS):
            label = f"{TOOL_KEYS[tool]} {TOOL_LABELS[tool]}"
            ttk.Radiobutton(
                tools,
                text=label,
                variable=self.tool_var,
                value=tool,
            ).grid(row=0, column=index, sticky="w", padx=(0, 12))

        ttk.Button(tools, text="导出 Dart 片段", command=self._export_dart).grid(
            row=0,
            column=len(TOOL_LABELS),
            sticky="e",
            padx=(16, 0),
        )
        ttk.Button(tools, text="导出 JSON", command=self._export_json).grid(
            row=0,
            column=len(TOOL_LABELS) + 1,
            sticky="e",
            padx=(8, 0),
        )

        board_frame = ttk.Frame(root)
        board_frame.grid(row=2, column=0, sticky="nsew", pady=(10, 0))
        board_frame.rowconfigure(0, weight=1)
        board_frame.columnconfigure(0, weight=1)

        self.canvas = tk.Canvas(
            board_frame,
            background="#ffffff",
            highlightthickness=1,
            highlightbackground="#cbd5e1",
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
        status.grid(row=3, column=0, sticky="ew", pady=(8, 0))

    def _bind_shortcuts(self):
        for tool, key in TOOL_KEYS.items():
            self.bind(key, lambda _event, selected=tool: self.tool_var.set(selected))
        self.bind("<Control-s>", lambda _event: self._export_dart())

    def _mark_level_number_custom(self, *_args):
        if self._updating_level_number:
            return

        self._level_number_is_custom = True

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
        self.canvas.configure(scrollregion=(0, 0, width, height))

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

    def _level_payload(self):
        self._refresh_auto_level_number()

        if self.player_position is None:
            raise ValueError("请先放置玩家。")

        player_row, player_column = self.player_position
        player_symbol = self.grid_data[player_row][player_column]
        if player_symbol in (SYMBOLS["wall"], SYMBOLS["outside"]):
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

        return {
            "number": self._safe_int(self.level_number_var.get(), 1, 1, 999),
            "title": self.level_title_var.get().strip() or "自定义关卡",
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

        with open(path, "w", encoding="utf-8") as file:
            json.dump(payload, file, ensure_ascii=False, indent=2)
            file.write("\n")

        self.status_var.set(f"已导出 JSON：{path}")
        self._refresh_auto_level_number()
        messagebox.showinfo("导出完成", f"已导出 JSON：\n{path}")

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

        snippet = self._dart_snippet(payload)
        with open(path, "w", encoding="utf-8") as file:
            file.write(snippet)

        self.clipboard_clear()
        self.clipboard_append(snippet)
        self.status_var.set(f"已导出 Dart 片段并复制到剪贴板：{path}")
        self._refresh_auto_level_number()
        messagebox.showinfo(
            "导出完成",
            f"已导出 Dart 片段，并复制到剪贴板：\n{path}",
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

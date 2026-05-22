from __future__ import annotations

from collections import deque
from dataclasses import dataclass, field
from enum import Enum
import heapq
from math import inf


class Move(Enum):
  up = (-1, 0, "U")
  down = (1, 0, "D")
  left = (0, -1, "L")
  right = (0, 1, "R")

  @property
  def delta_row(self) -> int:
    return self.value[0]

  @property
  def delta_column(self) -> int:
    return self.value[1]

  @property
  def symbol(self) -> str:
    return self.value[2]


MOVE_ORDER = (Move.up, Move.down, Move.left, Move.right)
BLOCK_TILES = {"#", "_"}
TARGET_TILES = {"T", ".", "+", "*"}
BOX_TILES = {"B", "$", "*"}


@dataclass(frozen=True, order=True)
class BoardPosition:
  row: int
  column: int

  def move(self, delta_row: int, delta_column: int) -> "BoardPosition":
    return BoardPosition(
      row=self.row + delta_row,
      column=self.column + delta_column,
    )

  def __str__(self) -> str:
    return f"{self.row},{self.column}"


@dataclass(frozen=True)
class SokobanLevel:
  layout: tuple[str, ...]
  initial_player_position: BoardPosition

  def __post_init__(self) -> None:
    object.__setattr__(self, "layout", tuple(self.layout))
    if not self.layout:
      raise ValueError("layout must not be empty")


@dataclass(slots=True)
class SolverState:
  player: BoardPosition
  boxes: frozenset[BoardPosition]
  state_key: str
  pushes: int = 0
  move_count: int = 0
  parent: "SolverState | None" = None
  segment: tuple[Move, ...] = ()


@dataclass(order=True, slots=True)
class _QueueNode:
  priority: int
  pushes: int
  move_count: int
  sequence: int
  state: SolverState = field(compare=False)


class SokobanSolver:
  def __init__(self, level: SokobanLevel):
    self.level = level
    self.rows = len(level.layout)
    self.cols = max((len(row) for row in level.layout), default=0)
    self.floor_tiles: set[BoardPosition] = set()
    self.targets: set[BoardPosition] = set()
    self.initial_boxes: set[BoardPosition] = set()
    self._parse_map()
    self.dead_tiles = frozenset(self._compute_dead_tiles())

  def _parse_map(self) -> None:
    for row_index, row_value in enumerate(self.level.layout):
      for column_index, tile in enumerate(row_value):
        position = BoardPosition(row=row_index, column=column_index)
        if tile not in BLOCK_TILES:
          self.floor_tiles.add(position)
        if tile in TARGET_TILES:
          self.targets.add(position)
        if tile in BOX_TILES:
          self.initial_boxes.add(position)

  def solve(self) -> list[Move] | None:
    initial_boxes = frozenset(self.initial_boxes)
    start_key = self._normalized_state_key(
      self.level.initial_player_position,
      initial_boxes,
    )
    start_state = SolverState(
      player=self.level.initial_player_position,
      boxes=initial_boxes,
      state_key=start_key,
    )

    if self._is_solved(initial_boxes):
      return []

    if self._has_deadlock(initial_boxes):
      return None

    best_cost_by_state = {start_key: (0, 0)}
    open_nodes = [
      _QueueNode(
        priority=self.heuristic(initial_boxes),
        pushes=0,
        move_count=0,
        sequence=0,
        state=start_state,
      )
    ]
    sequence = 1

    while open_nodes:
      current_node = heapq.heappop(open_nodes)
      current_state = current_node.state
      current_cost = (current_state.pushes, current_state.move_count)
      if best_cost_by_state.get(current_state.state_key) != current_cost:
        continue

      if self._is_solved(current_state.boxes):
        return self._reconstruct_solution(current_state)

      reachable_positions, parent_moves = self._compute_reachable_map(
        current_state.player,
        current_state.boxes,
      )
      candidates: list[
        tuple[int, int, BoardPosition, frozenset[BoardPosition], tuple[Move, ...]]
      ] = []

      for box_position in sorted(current_state.boxes):
        for move in MOVE_ORDER:
          player_push_position = box_position.move(
            -move.delta_row,
            -move.delta_column,
          )
          next_box_position = box_position.move(
            move.delta_row,
            move.delta_column,
          )

          if player_push_position not in reachable_positions:
            continue
          if not self._is_floor_tile(next_box_position):
            continue
          if next_box_position in current_state.boxes:
            continue
          if (
            next_box_position in self.dead_tiles
            and next_box_position not in self.targets
          ):
            continue

          next_boxes = set(current_state.boxes)
          next_boxes.remove(box_position)
          next_boxes.add(next_box_position)
          frozen_boxes = frozenset(next_boxes)

          if self._has_deadlock(
            frozen_boxes,
            moved_box=next_box_position,
          ):
            continue

          walk_segment = self._reconstruct_walk(
            parent_moves,
            player_push_position,
          )
          full_segment = (*walk_segment, move)
          candidates.append(
            (
              self.heuristic(
                frozen_boxes,
                pushed_from=box_position,
                pushed_to=next_box_position,
              ),
              len(full_segment),
              box_position,
              frozen_boxes,
              full_segment,
            )
          )

      candidates.sort(key=lambda item: (item[0], item[1], item[2]))

      for candidate_priority, _, next_player, next_boxes, segment in candidates:
        next_pushes = current_state.pushes + 1
        next_move_count = current_state.move_count + len(segment)
        next_key = self._normalized_state_key(next_player, next_boxes)
        next_cost = (next_pushes, next_move_count)

        if next_cost >= best_cost_by_state.get(next_key, (inf, inf)):
          continue

        best_cost_by_state[next_key] = next_cost
        next_state = SolverState(
          player=next_player,
          boxes=next_boxes,
          state_key=next_key,
          pushes=next_pushes,
          move_count=next_move_count,
          parent=current_state,
          segment=segment,
        )
        heapq.heappush(
          open_nodes,
          _QueueNode(
            priority=candidate_priority + next_pushes,
            pushes=next_pushes,
            move_count=next_move_count,
            sequence=sequence,
            state=next_state,
          ),
        )
        sequence += 1

    return None

  def heuristic(
    self,
    boxes: frozenset[BoardPosition],
    *,
    pushed_from: BoardPosition | None = None,
    pushed_to: BoardPosition | None = None,
  ) -> int:
    priority = self._minimum_target_distance_sum(boxes) * 8
    priority += sum(1 for box in boxes if box not in self.targets)

    if pushed_from is not None and pushed_to is not None:
      if pushed_to in self.targets:
        priority -= 5
      if pushed_from in self.targets and pushed_to not in self.targets:
        priority += 12

    return priority

  def _minimum_target_distance_sum(
    self,
    boxes: frozenset[BoardPosition],
  ) -> int:
    remaining_targets = list(self.targets)
    total_distance = 0
    sorted_boxes = sorted(
      boxes,
      key=lambda box: (
        self._nearest_target_distance(box, remaining_targets),
        box.row,
        box.column,
      ),
    )

    for box_position in sorted_boxes:
      if not remaining_targets:
        break

      best_target_index = 0
      best_distance = self._manhattan_distance(
        box_position,
        remaining_targets[0],
      )
      for target_index in range(1, len(remaining_targets)):
        distance = self._manhattan_distance(
          box_position,
          remaining_targets[target_index],
        )
        if distance < best_distance:
          best_target_index = target_index
          best_distance = distance

      total_distance += best_distance
      remaining_targets.pop(best_target_index)

    return total_distance

  def _nearest_target_distance(
    self,
    box_position: BoardPosition,
    targets: list[BoardPosition],
  ) -> int:
    if not targets:
      return 0
    return min(
      self._manhattan_distance(box_position, target_position)
      for target_position in targets
    )

  def _manhattan_distance(
    self,
    first: BoardPosition,
    second: BoardPosition,
  ) -> int:
    return abs(first.row - second.row) + abs(first.column - second.column)

  def _is_solved(self, boxes: frozenset[BoardPosition]) -> bool:
    return all(box in self.targets for box in boxes)

  def _normalized_state_key(
    self,
    player: BoardPosition,
    boxes: frozenset[BoardPosition],
  ) -> str:
    canonical_position = self._canonical_reachable_position(player, boxes)
    return f"{canonical_position.row},{canonical_position.column}|{self._positions_key(boxes)}"

  def _positions_key(self, positions: frozenset[BoardPosition]) -> str:
    return ";".join(str(position) for position in sorted(positions))

  def _canonical_reachable_position(
    self,
    player: BoardPosition,
    boxes: frozenset[BoardPosition],
  ) -> BoardPosition:
    reachable_positions, _ = self._compute_reachable_map(player, boxes)
    return min(reachable_positions) if reachable_positions else player

  def _compute_reachable_map(
    self,
    start: BoardPosition,
    boxes: frozenset[BoardPosition],
  ) -> tuple[
    set[BoardPosition],
    dict[BoardPosition, tuple[BoardPosition, Move] | None],
  ]:
    if not self._is_floor_tile(start) or start in boxes:
      return set(), {}

    reachable_positions = {start}
    parent_moves: dict[BoardPosition, tuple[BoardPosition, Move] | None] = {
      start: None,
    }
    pending_positions = deque([start])

    while pending_positions:
      current_position = pending_positions.popleft()
      for move in MOVE_ORDER:
        next_position = current_position.move(
          move.delta_row,
          move.delta_column,
        )
        if not self._is_floor_tile(next_position):
          continue
        if next_position in boxes or next_position in reachable_positions:
          continue

        reachable_positions.add(next_position)
        parent_moves[next_position] = (current_position, move)
        pending_positions.append(next_position)

    return reachable_positions, parent_moves

  def _reconstruct_walk(
    self,
    parent_moves: dict[BoardPosition, tuple[BoardPosition, Move] | None],
    destination: BoardPosition,
  ) -> tuple[Move, ...]:
    walk: list[Move] = []
    current_position = destination

    while True:
      parent_entry = parent_moves.get(current_position)
      if parent_entry is None:
        break

      previous_position, move = parent_entry
      walk.append(move)
      current_position = previous_position

    walk.reverse()
    return tuple(walk)

  def _reconstruct_solution(self, state: SolverState) -> list[Move]:
    reversed_segments: list[tuple[Move, ...]] = []
    current_state: SolverState | None = state

    while current_state is not None and current_state.parent is not None:
      reversed_segments.append(current_state.segment)
      current_state = current_state.parent

    solution: list[Move] = []
    for segment in reversed(reversed_segments):
      solution.extend(segment)

    return solution

  def _compute_dead_tiles(self) -> set[BoardPosition]:
    reachable_positions = {
      target_position
      for target_position in self.targets
      if self._is_floor_tile(target_position)
    }
    pending_positions = deque(reachable_positions)

    while pending_positions:
      current_position = pending_positions.popleft()

      for move in MOVE_ORDER:
        previous_box_position = current_position.move(
          -move.delta_row,
          -move.delta_column,
        )
        player_support_position = previous_box_position.move(
          -move.delta_row,
          -move.delta_column,
        )

        if not self._is_floor_tile(previous_box_position):
          continue
        if not self._is_floor_tile(player_support_position):
          continue
        if previous_box_position in reachable_positions:
          continue

        reachable_positions.add(previous_box_position)
        pending_positions.append(previous_box_position)

    dead_tiles: set[BoardPosition] = set()
    for floor_position in self.floor_tiles:
      if floor_position in self.targets:
        continue
      if floor_position not in reachable_positions or self._is_corner_deadlock(
        floor_position
      ):
        dead_tiles.add(floor_position)

    return dead_tiles

  def _has_deadlock(
    self,
    boxes: frozenset[BoardPosition],
    *,
    moved_box: BoardPosition | None = None,
  ) -> bool:
    if self._is_solved(boxes):
      return False

    for box_position in boxes:
      if box_position in self.targets:
        continue
      if box_position in self.dead_tiles or self._is_corner_deadlock(box_position):
        return True

    if moved_box is not None:
      return self._forms_frozen_square_deadlock(boxes, moved_box)

    return any(
      self._forms_frozen_square_deadlock(boxes, box_position)
      for box_position in boxes
    )

  def _forms_frozen_square_deadlock(
    self,
    boxes: frozenset[BoardPosition],
    anchor: BoardPosition,
  ) -> bool:
    top_left_candidates = (
      anchor,
      anchor.move(-1, 0),
      anchor.move(0, -1),
      anchor.move(-1, -1),
    )

    for top_left in top_left_candidates:
      square = (
        top_left,
        top_left.move(0, 1),
        top_left.move(1, 0),
        top_left.move(1, 1),
      )
      if any(not self._is_inside_layout(position) for position in square):
        continue

      is_frozen_square = all(
        not self._is_floor_tile(position) or position in boxes
        for position in square
      )
      if not is_frozen_square:
        continue

      has_off_target_box = any(
        position in boxes and position not in self.targets
        for position in square
      )
      if has_off_target_box:
        return True

    return False

  def _is_corner_deadlock(self, position: BoardPosition) -> bool:
    if position in self.targets or not self._is_floor_tile(position):
      return False

    blocked_above = self._is_static_blocker(position.move(-1, 0))
    blocked_below = self._is_static_blocker(position.move(1, 0))
    blocked_left = self._is_static_blocker(position.move(0, -1))
    blocked_right = self._is_static_blocker(position.move(0, 1))
    return (blocked_above or blocked_below) and (blocked_left or blocked_right)

  def _is_static_blocker(self, position: BoardPosition) -> bool:
    return position not in self.floor_tiles

  def _is_floor_tile(self, position: BoardPosition) -> bool:
    return position in self.floor_tiles

  def _is_inside_layout(self, position: BoardPosition) -> bool:
    if position.row < 0 or position.row >= self.rows:
      return False
    return 0 <= position.column < len(self.level.layout[position.row])


def format_moves(moves: list[Move]) -> str:
  return "".join(move.symbol for move in moves)


def main() -> int:
  demo_level = SokobanLevel(
    layout=(
      "#####",
      "#   #",
      "# B #",
      "# T #",
      "#   #",
      "#####",
    ),
    initial_player_position=BoardPosition(row=1, column=1),
  )
  solver = SokobanSolver(demo_level)
  solution = solver.solve()
  if solution is None:
    print("No solution found.")
    return 1

  print(f"Solved in {len(solution)} moves: {format_moves(solution)}")
  return 0


if __name__ == "__main__":
  raise SystemExit(main())

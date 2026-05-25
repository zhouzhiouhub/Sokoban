from __future__ import annotations

from collections import deque
from dataclasses import dataclass, field
from enum import Enum
import heapq
from math import inf
from time import monotonic


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
UNREACHABLE_TARGET_COST = 1_000_000_000
EXACT_MATCHING_BOX_LIMIT = 12
HEURISTIC_DISTANCE_WEIGHT = 8
SOLVER_DEADLINE_CHECK_INTERVAL = 256


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


class SokobanSolveTimeout(TimeoutError):
  pass


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


@dataclass(frozen=True, slots=True)
class SokobanPush:
  brick_position: BoardPosition
  move: Move

  @property
  def next_brick_position(self) -> BoardPosition:
    return self.brick_position.move(
      self.move.delta_row,
      self.move.delta_column,
    )


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
    self.target_distances = self._compute_target_distances()
    self.dead_tiles = frozenset(self._compute_dead_tiles())
    self._base_heuristic_cache: dict[frozenset[BoardPosition], int] = {}
    self._deadlock_cache: dict[
      tuple[frozenset[BoardPosition], BoardPosition | None],
      bool,
    ] = {}

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

  def solve_pushes(
    self,
    *,
    max_seconds: float | None = None,
    max_visited_states: int | None = None,
  ) -> list[SokobanPush] | None:
    start_time = monotonic()
    expanded_states = 0
    initial_boxes = frozenset(self.initial_boxes)
    start_key, start_reachable_positions = self._normalized_state_key_and_reachable(
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

    initial_priority = self.heuristic(initial_boxes)
    if initial_priority >= UNREACHABLE_TARGET_COST:
      return None

    visited_states = {start_key}
    last_push_by_state: dict[str, SokobanPush] = {}
    reachable_positions_by_state = {start_key: start_reachable_positions}
    open_nodes = [
      _QueueNode(
        priority=initial_priority,
        pushes=0,
        move_count=0,
        sequence=0,
        state=start_state,
      )
    ]
    sequence = 1

    while open_nodes:
      expanded_states += 1
      if expanded_states % SOLVER_DEADLINE_CHECK_INTERVAL == 0:
        self._check_search_limits(
          start_time=start_time,
          max_seconds=max_seconds,
          visited_count=len(visited_states),
          max_visited_states=max_visited_states,
        )

      current_node = heapq.heappop(open_nodes)
      current_state = current_node.state

      if self._is_solved(current_state.boxes):
        return self._reconstruct_push_solution(
          current_state,
          last_push_by_state,
        )

      reachable_positions = reachable_positions_by_state.pop(
        current_state.state_key,
        None,
      )
      if reachable_positions is None:
        reachable_positions, _ = self._compute_reachable_map(
          current_state.player,
          current_state.boxes,
        )
      candidates: list[
        tuple[int, BoardPosition, Move, frozenset[BoardPosition]]
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

          candidate_priority = self.heuristic(
            frozen_boxes,
            pushed_from=box_position,
            pushed_to=next_box_position,
          )
          if candidate_priority >= UNREACHABLE_TARGET_COST:
            continue

          candidates.append(
            (candidate_priority, box_position, move, frozen_boxes)
          )

      candidates.sort(key=lambda item: (item[0], item[1], item[2].value[2]))

      for candidate_priority, box_position, move, next_boxes in candidates:
        next_pushes = current_state.pushes + 1
        next_player = box_position
        next_key, next_reachable_positions = (
          self._normalized_state_key_and_reachable(next_player, next_boxes)
        )

        if next_key in visited_states:
          continue

        visited_states.add(next_key)
        if max_visited_states is not None and len(visited_states) > max_visited_states:
          raise SokobanSolveTimeout(
            f"求解搜索超过 {max_visited_states} 个状态，"
            "可能有解但当前内置求解器无法在限制内找到。",
          )

        reachable_positions_by_state[next_key] = next_reachable_positions
        next_state = SolverState(
          player=next_player,
          boxes=next_boxes,
          state_key=next_key,
          pushes=next_pushes,
          parent=current_state,
        )
        last_push_by_state[next_key] = SokobanPush(
          brick_position=box_position,
          move=move,
        )
        heapq.heappush(
          open_nodes,
          _QueueNode(
            priority=candidate_priority + next_pushes,
            pushes=next_pushes,
            move_count=0,
            sequence=sequence,
            state=next_state,
          ),
        )
        sequence += 1

    return None

  def _check_search_limits(
    self,
    *,
    start_time: float,
    max_seconds: float | None,
    visited_count: int,
    max_visited_states: int | None,
  ) -> None:
    if max_seconds is not None and monotonic() - start_time > max_seconds:
      raise SokobanSolveTimeout(
        f"求解超过 {max_seconds:g} 秒，可能有解但当前内置求解器无法在限制内找到。",
      )

    if max_visited_states is not None and visited_count > max_visited_states:
      raise SokobanSolveTimeout(
        f"求解搜索超过 {max_visited_states} 个状态，"
        "可能有解但当前内置求解器无法在限制内找到。",
      )

  def heuristic(
    self,
    boxes: frozenset[BoardPosition],
    *,
    pushed_from: BoardPosition | None = None,
    pushed_to: BoardPosition | None = None,
  ) -> int:
    priority = self._base_heuristic(boxes)

    if pushed_from is not None and pushed_to is not None:
      if pushed_to in self.targets:
        priority -= 5
      if pushed_from in self.targets and pushed_to not in self.targets:
        priority += 12

    return priority

  def _base_heuristic(self, boxes: frozenset[BoardPosition]) -> int:
    cached_priority = self._base_heuristic_cache.get(boxes)
    if cached_priority is not None:
      return cached_priority

    minimum_distance = self._minimum_target_distance_sum(boxes)
    if minimum_distance >= UNREACHABLE_TARGET_COST:
      priority = UNREACHABLE_TARGET_COST
    else:
      priority = minimum_distance * HEURISTIC_DISTANCE_WEIGHT
      priority += sum(1 for box in boxes if box not in self.targets)

    self._base_heuristic_cache[boxes] = priority
    return priority

  def _minimum_target_distance_sum(
    self,
    boxes: frozenset[BoardPosition],
  ) -> int:
    if not boxes:
      return 0

    if len(boxes) <= EXACT_MATCHING_BOX_LIMIT:
      return self._minimum_target_distance_matching(boxes)

    remaining_targets = list(self.targets)
    total_distance = 0
    sorted_boxes = sorted(
      boxes,
      key=lambda box: (
        self._nearest_target_push_distance(box, remaining_targets),
        box.row,
        box.column,
      ),
    )

    for box_position in sorted_boxes:
      if not remaining_targets:
        break

      best_target_index = 0
      best_distance = self._target_push_distance(
        box_position,
        remaining_targets[0],
      )
      for target_index in range(1, len(remaining_targets)):
        distance = self._target_push_distance(
          box_position,
          remaining_targets[target_index],
        )
        if distance < best_distance:
          best_target_index = target_index
          best_distance = distance

      if best_distance >= UNREACHABLE_TARGET_COST:
        return UNREACHABLE_TARGET_COST

      total_distance += best_distance
      remaining_targets.pop(best_target_index)

    return total_distance

  def _minimum_target_distance_matching(
    self,
    boxes: frozenset[BoardPosition],
  ) -> int:
    sorted_boxes = sorted(boxes)
    sorted_targets = sorted(self.targets)
    target_count = len(sorted_targets)
    costs: list[list[int]] = []

    for box_position in sorted_boxes:
      box_costs = [
        self._target_push_distance(box_position, target_position)
        for target_position in sorted_targets
      ]
      if all(cost >= UNREACHABLE_TARGET_COST for cost in box_costs):
        return UNREACHABLE_TARGET_COST
      costs.append(box_costs)

    best_cost_by_mask = {0: 0}
    for box_index, box_costs in enumerate(costs):
      next_cost_by_mask: dict[int, int] = {}
      for mask, cost in best_cost_by_mask.items():
        for target_index in range(target_count):
          if mask & (1 << target_index):
            continue

          target_cost = box_costs[target_index]
          if target_cost >= UNREACHABLE_TARGET_COST:
            continue

          next_mask = mask | (1 << target_index)
          next_cost = cost + target_cost
          if next_cost < next_cost_by_mask.get(next_mask, UNREACHABLE_TARGET_COST):
            next_cost_by_mask[next_mask] = next_cost

      if not next_cost_by_mask:
        return UNREACHABLE_TARGET_COST

      best_cost_by_mask = next_cost_by_mask

    return min(best_cost_by_mask.values(), default=UNREACHABLE_TARGET_COST)

  def _nearest_target_push_distance(
    self,
    box_position: BoardPosition,
    targets: list[BoardPosition],
  ) -> int:
    if not targets:
      return 0
    return min(
      self._target_push_distance(box_position, target_position)
      for target_position in targets
    )

  def _target_push_distance(
    self,
    box_position: BoardPosition,
    target_position: BoardPosition,
  ) -> int:
    return self.target_distances.get(target_position, {}).get(
      box_position,
      UNREACHABLE_TARGET_COST,
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

  def _normalized_state_key_and_reachable(
    self,
    player: BoardPosition,
    boxes: frozenset[BoardPosition],
  ) -> tuple[str, set[BoardPosition]]:
    reachable_positions, _ = self._compute_reachable_map(player, boxes)
    canonical_position = min(reachable_positions) if reachable_positions else player
    return (
      f"{canonical_position.row},{canonical_position.column}|{self._positions_key(boxes)}",
      reachable_positions,
    )

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

  def _reconstruct_push_solution(
    self,
    state: SolverState,
    last_push_by_state: dict[str, SokobanPush],
  ) -> list[SokobanPush]:
    reversed_pushes: list[SokobanPush] = []
    current_state: SolverState | None = state

    while current_state is not None and current_state.parent is not None:
      reversed_pushes.append(last_push_by_state[current_state.state_key])
      current_state = current_state.parent

    reversed_pushes.reverse()
    return reversed_pushes

  def _compute_target_distances(
    self,
  ) -> dict[BoardPosition, dict[BoardPosition, int]]:
    return {
      target_position: self._compute_pull_distances_from_target(target_position)
      for target_position in self.targets
      if self._is_floor_tile(target_position)
    }

  def _compute_pull_distances_from_target(
    self,
    target_position: BoardPosition,
  ) -> dict[BoardPosition, int]:
    distances = {target_position: 0}
    pending_positions = deque([target_position])

    while pending_positions:
      current_position = pending_positions.popleft()
      current_distance = distances[current_position]

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
        if previous_box_position in distances:
          continue

        distances[previous_box_position] = current_distance + 1
        pending_positions.append(previous_box_position)

    return distances

  def _compute_dead_tiles(self) -> set[BoardPosition]:
    dead_tiles: set[BoardPosition] = set()
    for floor_position in self.floor_tiles:
      if floor_position in self.targets:
        continue
      if (
        all(
          distances.get(floor_position, UNREACHABLE_TARGET_COST)
          >= UNREACHABLE_TARGET_COST
          for distances in self.target_distances.values()
        )
        or self._is_corner_deadlock(floor_position)
      ):
        dead_tiles.add(floor_position)

    return dead_tiles

  def _has_deadlock(
    self,
    boxes: frozenset[BoardPosition],
    *,
    moved_box: BoardPosition | None = None,
  ) -> bool:
    cache_key = (boxes, moved_box)
    cached_deadlock = self._deadlock_cache.get(cache_key)
    if cached_deadlock is not None:
      return cached_deadlock

    if self._is_solved(boxes):
      self._deadlock_cache[cache_key] = False
      return False

    for box_position in boxes:
      if box_position in self.targets:
        continue
      if box_position in self.dead_tiles or self._is_corner_deadlock(box_position):
        self._deadlock_cache[cache_key] = True
        return True

    if moved_box is not None:
      result = self._forms_frozen_square_deadlock(
        boxes,
        moved_box,
      ) or self._forms_freeze_deadlock(boxes, moved_box)
      self._deadlock_cache[cache_key] = result
      return result

    result = any(
      self._forms_frozen_square_deadlock(boxes, box_position)
      or self._forms_freeze_deadlock(boxes, box_position)
      for box_position in boxes
    )
    self._deadlock_cache[cache_key] = result
    return result

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

  def _forms_freeze_deadlock(
    self,
    boxes: frozenset[BoardPosition],
    anchor: BoardPosition,
  ) -> bool:
    affected_boxes = self._freeze_connected_boxes(boxes, anchor)
    for box_position in affected_boxes:
      if box_position in self.targets:
        continue

      probe = _FreezeProbe(self, boxes)
      if probe.is_frozen(box_position):
        return True

    return False

  def _freeze_connected_boxes(
    self,
    boxes: frozenset[BoardPosition],
    anchor: BoardPosition,
  ) -> set[BoardPosition]:
    if anchor not in boxes:
      return set()

    connected_boxes = {anchor}
    pending_positions = deque([anchor])
    while pending_positions:
      current_position = pending_positions.popleft()
      for move in MOVE_ORDER:
        next_position = current_position.move(
          move.delta_row,
          move.delta_column,
        )
        if next_position in boxes and next_position not in connected_boxes:
          connected_boxes.add(next_position)
          pending_positions.append(next_position)

    return connected_boxes

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


class _FreezeProbe:
  def __init__(
    self,
    solver: SokobanSolver,
    boxes: frozenset[BoardPosition],
  ) -> None:
    self.solver = solver
    self.boxes = boxes
    self.axis_checks: set[tuple[BoardPosition, str]] = set()

  def is_frozen(self, position: BoardPosition) -> bool:
    return self._axis_blocked(position, "horizontal") and self._axis_blocked(
      position,
      "vertical",
    )

  def _axis_blocked(self, position: BoardPosition, axis: str) -> bool:
    check_key = (position, axis)
    if check_key in self.axis_checks:
      return True

    self.axis_checks.add(check_key)
    directions = (
      (Move.left, Move.right)
      if axis == "horizontal"
      else (Move.up, Move.down)
    )
    opposite_axis = "vertical" if axis == "horizontal" else "horizontal"

    for move in directions:
      next_position = position.move(move.delta_row, move.delta_column)
      if (
        self.solver._is_static_blocker(next_position)
        or next_position in self.solver.dead_tiles
      ):
        continue

      if next_position not in self.boxes:
        return False

      if not self._axis_blocked(next_position, opposite_axis):
        return False

    return True


def format_moves(moves: list[Move]) -> str:
  return "".join(move.symbol for move in moves)


def format_pushes(pushes: list[SokobanPush]) -> str:
  return ";".join(
    f"{push.brick_position.row},{push.brick_position.column},{push.move.symbol}"
    for push in pushes
  )


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
  solution = solver.solve_pushes()
  if solution is None:
    print("No solution found.")
    return 1

  print(f"Solved in {len(solution)} pushes: {format_pushes(solution)}")
  return 0


if __name__ == "__main__":
  raise SystemExit(main())

class LevelCopy {
  const LevelCopy({required this.title, required this.description});

  final String title;
  final String description;
}

const List<LevelCopy> levelCopy = [
  LevelCopy(title: '第一关', description: '把上下左右四个箱子分别推到对应目标点。'),
];

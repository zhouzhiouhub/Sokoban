class LevelCopy {
  const LevelCopy({required this.title, required this.description});

  final String title;
  final String description;
}

const List<LevelCopy> levelCopy = [
  LevelCopy(title: '第一关', description: '把箱子推到目标点，部分箱子已在目标点上。'),
  LevelCopy(title: '第二关', description: '规划路线，把三个箱子推到三处目标点。'),
  LevelCopy(title: '第三关', description: '穿过左右房间，把两个箱子推到左侧目标点。'),
];

const String appName = '箱径';

String appLevelTitle(String levelTitle, {bool isComplete = false}) {
  final completionSuffix = isComplete ? ' 已过关' : '';
  return '$appName - $levelTitle$completionSuffix';
}

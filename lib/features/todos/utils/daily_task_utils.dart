class DailyTask {
  const DailyTask({
    required this.title,
    required this.completed,
    this.subtitle,
    this.progressVal,
    this.progressLabel,
  });
  final String title;
  final bool completed;
  final String? subtitle;
  final double? progressVal;
  final String? progressLabel;
}

List<DailyTask> buildDailyTasks({
  required int mealsToday,
  required int waterTodayMl,
  required int goalMl,
}) {
  return [
    DailyTask(
      title: 'Log all meals today',
      completed: mealsToday > 0,
      subtitle: mealsToday > 0
          ? '$mealsToday meal${mealsToday == 1 ? '' : 's'} logged'
          : 'No meals logged yet',
    ),
    DailyTask(
      title: 'Drink at least 2000 ml water',
      completed: waterTodayMl >= 2000,
      subtitle: '$waterTodayMl ml / 2000 ml',
    ),
    DailyTask(
      title: 'Track at least 3 meals today',
      completed: mealsToday >= 3,
      subtitle: '$mealsToday / 3 meals tracked',
    ),
    DailyTask(
      title: 'Reach your hydration goal',
      completed: waterTodayMl >= goalMl,
      subtitle: '$waterTodayMl ml / $goalMl ml',
    ),
  ];
}

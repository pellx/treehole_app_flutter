/// 广场页「左侧拉出刷新球」的交互与视觉参数。
///
/// 交互过程：
///   1. 手指在屏幕左侧 [triggerAreaWidth] 范围内向下滑动。
///   2. 随着下拉距离增加，刷新球从屏幕左外侧逐渐滑入，直到下拉距离达到
///      [pullThreshold] 时球完全显示并停在 [ballFinalLeftInset] 位置。
///   3. 继续下拉不再改变球的位置（进度被钳制在 1.0）。
///   4. 松手时如果进度 ≥ 1.0，触发刷新并显示加载指示器；否则球收回。
class AppSquareRefreshTheme {
  const AppSquareRefreshTheme._();

  /// 左侧触发区域的宽度（从屏幕左边缘往右算）。
  static const double triggerAreaWidth = 20;

  /// 需要下拉多少像素，刷新球才算完全拉出并触发刷新。
  static const double pullThreshold = 90;

  /// 刷新球直径。
  static const double ballSize = 48;

  /// 刷新球完全拉出后，球左侧到屏幕左边缘的距离。
  static const double ballFinalLeftInset = 16;

  /// 刷新球阴影的不透明度。
  static const double shadowOpacity = 0.15;

  /// 刷新图标的大小。
  static const double iconSize = 24;

  /// 加载指示器的大小。
  static const double indicatorSize = 22;

  /// 加载指示器的描边宽度。
  static const double indicatorStrokeWidth = 2;
}

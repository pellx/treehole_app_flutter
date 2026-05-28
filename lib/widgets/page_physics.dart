import 'package:flutter/widgets.dart';
import '../theme/app_dimens.dart';

class FastPageScrollPhysics extends PageScrollPhysics {
  @override
  FastPageScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return FastPageScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  SpringDescription get spring => SpringDescription.withDampingRatio(
        mass: AppDimens.pageSnapMass,
        stiffness: AppDimens.pageSnapStiffness,
        ratio: AppDimens.pageSnapDampingRatio,
      );

  const FastPageScrollPhysics({super.parent});

  @override
  Simulation? createBallisticSimulation(
      ScrollMetrics position, double velocity) {
    final Tolerance tolerance = toleranceFor(position);
    final double rawPage = position.pixels / position.viewportDimension;
    final double maxPage = position.maxScrollExtent / position.viewportDimension;

    // 1. 越界且继续往外推 → 自己用可控速度弹回
    if (position.pixels < 0.0 && velocity <= tolerance.velocity) {
      return _bounceTo(position, 0.0, velocity);
    }
    if (position.pixels > position.maxScrollExtent && velocity >= -tolerance.velocity) {
      return _bounceTo(position, position.maxScrollExtent, velocity);
    }

    // 2. 接近整数页 + 有方向速度 → 自己截胡，不调 super
    final dist = (rawPage - rawPage.roundToDouble()).abs();
    if (dist < 0.05 && velocity.abs() > 0) {
      double targetPage = velocity > 0
          ? rawPage.roundToDouble() + 1
          : rawPage.roundToDouble() - 1;
      targetPage = targetPage.clamp(0.0, maxPage);
      return _snapTo(position, targetPage, velocity);
    }

    // 3. 非整数页 + 有速度 → 用系统默认翻页
    if (velocity.abs() > tolerance.velocity) {
      return super.createBallisticSimulation(position, velocity);
    }

    // 4. 偏离整数页 + 无速度 → 自动归位
    if (dist > tolerance.distance / position.viewportDimension) {
      final nearest = rawPage.roundToDouble().clamp(0.0, maxPage);
      return _snapTo(position, nearest, velocity);
    }

    return null;
  }

  SpringDescription get _bounceSpring => SpringDescription.withDampingRatio(
        mass: AppDimens.bounceMass,
        stiffness: AppDimens.bounceStiffness,
        ratio: AppDimens.bounceDampingRatio,
      );

  Simulation _snapTo(ScrollMetrics position, double targetPage, double velocity) {
    return ScrollSpringSimulation(
      spring,
      position.pixels,
      targetPage * position.viewportDimension,
      velocity,
      tolerance: toleranceFor(position),
    );
  }

  Simulation _bounceTo(ScrollMetrics position, double targetPixels, double velocity) {
    return ScrollSpringSimulation(
      _bounceSpring,
      position.pixels,
      targetPixels,
      velocity,
      tolerance: toleranceFor(position),
    );
  }
}

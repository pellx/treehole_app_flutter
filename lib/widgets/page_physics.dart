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
}

import 'package:flutter/foundation.dart';

/// 账户展示变更（被踢切号 / 登录切换后），贴文页与用户页应重载昵称、头像等
final ValueNotifier<int> accountDisplayEpoch = ValueNotifier<int>(0);

void notifyAccountDisplayChanged() {
  accountDisplayEpoch.value++;
}

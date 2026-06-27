/// 内容审核拒绝文案映射
///
/// key: 阿里云审核返回的 label（全部转为小写匹配）
/// value: 面向用户的友好提示文案
const Map<String, String> moderationFeedback = {
  // === 色情 ===
  'pornographic_adultcontent': '图片包含成人色情内容',
  'pornographic_adult': '内容包含成人色情信息',
  'sexual_content': '内容包含不当性暗示',
  'porn': '内容包含色情信息',

  // === 暴力 ===
  'violent_weapons': '内容涉及武器暴力',
  'violence': '内容包含暴力信息',

  // === 违禁 ===
  'contraband_act': '内容涉及违禁物品',
  'contraband': '内容涉及违禁物品',

  // === 政治 ===
  'political_n': '内容包含政治敏感信息',
  'political_figure': '内容涉及敏感人物',
  'politics': '内容包含政治敏感信息',

  // === 暴恐 ===
  'terrorism': '内容涉及暴恐信息',

  // === 广告/引流 ===
  'ad': '请勿发布广告营销内容',
  'pt_to_sites': '请勿发布引流信息',

  // === 辱骂 ===
  'abuse': '请勿发布侮辱谩骂内容',

  // === 灌水 ===
  'spam': '请勿重复发布相同内容',
  'meaningless': '请填写有意义的标题和正文',
  'nonsense': '请填写有意义的标题和正文',
};

/// 根据后端返回的审核拒绝原因文本，提取 label 并返回对应文案
///
/// 后端返回格式如: "图片违规: pornographic_adultContent(95%)"
/// 或: "内容违规: political_n(100%), political_figure(100%)"
String getModerationMessage(String rawReason) {
  if (rawReason.isEmpty) {
    return '内容包含违规信息 ';
  }

  // 提取 body 文本（去掉前缀如 "图片违规: " 或 "内容违规: "）
  final colonIndex = rawReason.indexOf(': ');
  final body = colonIndex >= 0 ? rawReason.substring(colonIndex + 2) : rawReason;

  // 按逗号分割，取第一个标签
  final firstLabel = body.split(',').first.split('(').first.trim().toLowerCase();

  return moderationFeedback[firstLabel] ?? '内容包含违规信息';
}

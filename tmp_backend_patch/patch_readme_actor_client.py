from pathlib import Path

p = Path('/var/www/treehole-nest/README.md')
text = p.read_text(encoding='utf-8')
marker = '### 客户端处理'
idx = text.find(marker)
if idx < 0:
    raise SystemExit('section not found')
# find first numbered item after section
start = text.find('\n1. ', idx)
if start < 0:
    raise SystemExit('item1 not found')
end = text.find('\n2. ', start)
if end < 0:
    raise SystemExit('item2 not found')
old = text[start + 1 : end]
print('OLD:', repr(old[:120]))
new = (
    '1. 收到 `binding.unbound` → 清该账户本地 session，退回登录 / 账户列表；'
    '**弹窗提示被踢**，并展示踢人者信息（优先 `actor_device_display_name`，'
    '其次 `actor_device_name` / `actor_brand`+`actor_model`，可附 `actor_ip`）。'
    '`local_unbind_due` 说明本机等待期到期。'
)
text = text[: start + 1] + new + text[end:]
p.write_text(text, encoding='utf-8')
print('updated')

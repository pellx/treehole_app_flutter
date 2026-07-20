#!/usr/bin/env python3
"""user2device 响应增加 users.created_at"""
from pathlib import Path

p = Path("/var/www/treehole-nest/src/user/user.service.binding.ts")
text = p.read_text(encoding="utf-8")

old_type = """      user_token: string;
      user_display_id: string | null;
    }>;"""

new_type = """      user_token: string;
      user_display_id: string | null;
      created_at: string;
    }>;"""

old_body = """            user_token: u.user_token,
            user_display_id: u.user_display_id ?? null,
          },"""

new_body = """            user_token: u.user_token,
            user_display_id: u.user_display_id ?? null,
            created_at: new Date(u.created_at).toISOString(),
          },"""

if old_type not in text:
    raise SystemExit("type block not found")
if old_body not in text:
    raise SystemExit("body block not found")

text = text.replace(old_type, new_type, 1).replace(old_body, new_body, 1)
p.write_text(text, encoding="utf-8")
print("OK")

from pathlib import Path

login = Path('/var/www/treehole-nest/src/user/user.service.login.ts')
lt = login.read_text(encoding='utf-8')

old_vs = """  /** 验证 session 是否有效，返回 user_id */
  async validateSession(sessionId: number, sessionSecret: string): Promise<number> {
    const raw = await this.redisService.client.get(`session:${sessionId}`);
    if (!raw) throw new UnauthorizedException('SESSION_INVALID');

    const data = JSON.parse(raw);
    const hash = createHash('sha256').update(sessionSecret).digest('hex');
    if (hash !== data.session_secret_hash) {
      throw new UnauthorizedException('SESSION_INVALID');
    }
    return data.user_id;
  }"""

new_vs = """  /** 验证 session 是否有效，返回 user_id + device_id */
  async validateSession(
    sessionId: number,
    sessionSecret: string,
  ): Promise<{ user_id: number; device_id: number }> {
    const raw = await this.redisService.client.get(`session:${sessionId}`);
    if (!raw) throw new UnauthorizedException('SESSION_INVALID');

    const data = JSON.parse(raw);
    const hash = createHash('sha256').update(sessionSecret).digest('hex');
    if (hash !== data.session_secret_hash) {
      throw new UnauthorizedException('SESSION_INVALID');
    }
    if (data.user_id == null || data.device_id == null) {
      throw new UnauthorizedException('SESSION_INVALID');
    }
    return { user_id: data.user_id, device_id: data.device_id };
  }"""

if old_vs not in lt:
    if 'device_id: data.device_id' in lt:
        print('login already patched')
    else:
        raise SystemExit('validateSession pattern missing')
else:
    lt = lt.replace(old_vs, new_vs, 1)
    print('validateSession patched')

old_ep = """  async validateSessionEndpoint(dto: SessionValidateDto): Promise<{ valid: boolean; user_id: number }> {
    const userId = await this.validateSession(dto.session_id, dto.session_secret);
    return { valid: true, user_id: userId };
  }"""
new_ep = """  async validateSessionEndpoint(dto: SessionValidateDto): Promise<{ valid: boolean; user_id: number }> {
    const session = await this.validateSession(dto.session_id, dto.session_secret);
    return { valid: true, user_id: session.user_id };
  }"""
if old_ep in lt:
    lt = lt.replace(old_ep, new_ep, 1)
    print('validateSessionEndpoint patched')
elif 'session.user_id' in lt:
    print('validateSessionEndpoint already patched')
else:
    raise SystemExit('validateSessionEndpoint pattern missing')

login.write_text(lt, encoding='utf-8')
print('done')

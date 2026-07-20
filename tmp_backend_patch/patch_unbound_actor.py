from pathlib import Path

bs = Path('/var/www/treehole-nest/src/user/user.service.binding.ts')
bt = bs.read_text(encoding='utf-8')

# Insert actorDeviceId param
old_sig = """  private async kickDeviceAfterUnbind(
    userId: number,
    deviceId: number,
    bindingId: number,
    reason: BindingUnboundReason,
  ): Promise<void> {"""
new_sig = """  private async kickDeviceAfterUnbind(
    userId: number,
    deviceId: number,
    bindingId: number,
    reason: BindingUnboundReason,
    actorDeviceId?: number | null,
  ): Promise<void> {"""
if old_sig not in bt:
    raise SystemExit('sig not found')
bt = bt.replace(old_sig, new_sig, 1)

old_notify = """    this.realtimeService.notifyDeviceUnbound({
      user_id: userId,
      device_id: deviceId,
      binding_id: bindingId,
      reason,
      at: new Date().toISOString(),
    });
  }"""
new_notify = """    let actor_device_id: number | null =
      actorDeviceId != null && Number.isFinite(actorDeviceId)
        ? Number(actorDeviceId)
        : null;
    let actor_device_display_name: string | null = null;
    let actor_device_name: string | null = null;
    if (actor_device_id != null) {
      const actorBinding = await this.bindingRepo.findOne({
        where: { user_id: userId, device_id: actor_device_id },
      });
      actor_device_display_name = actorBinding?.device_display_name ?? null;
      const actorDevice = await this.deviceRepo.findOne({
        where: { device_id: actor_device_id },
      });
      actor_device_name = actorDevice?.device_name ?? null;
    }

    this.realtimeService.notifyDeviceUnbound({
      user_id: userId,
      device_id: deviceId,
      binding_id: bindingId,
      reason,
      at: new Date().toISOString(),
      actor_device_id,
      actor_device_display_name,
      actor_device_name,
    });
  }"""
if old_notify not in bt:
    raise SystemExit('notify block not found')
bt = bt.replace(old_notify, new_notify, 1)

old_remote = """      await this.kickDeviceAfterUnbind(
        userId,
        binding.device_id,
        binding.id,
        'remote_unbind',
      );"""
new_remote = """      await this.kickDeviceAfterUnbind(
        userId,
        binding.device_id,
        binding.id,
        'remote_unbind',
        sessionDeviceId,
      );"""
if old_remote not in bt:
    raise SystemExit('remote call not found')
bt = bt.replace(old_remote, new_remote, 1)

old_local = """    await this.kickDeviceAfterUnbind(
      binding.user_id,
      binding.device_id,
      binding.id,
      'local_unbind_due',
    );"""
new_local = """    await this.kickDeviceAfterUnbind(
      binding.user_id,
      binding.device_id,
      binding.id,
      'local_unbind_due',
      binding.device_id,
    );"""
if old_local not in bt:
    raise SystemExit('local call not found')
bt = bt.replace(old_local, new_local, 1)

bs.write_text(bt, encoding='utf-8')
print('binding patch ok')

# README snippet for binding.unbound
readme = Path('/var/www/treehole-nest/README.md')
rt = readme.read_text(encoding='utf-8')
old_ex = """```json
{
  \"event\": \"binding.unbound\",
  \"user_id\": 1,
  \"device_id\": 8,
  \"binding_id\": 12,
  \"reason\": \"remote_unbind\",
  \"at\": \"2026-07-20T01:00:00.000Z\"
}
```"""
new_ex = """```json
{
  \"event\": \"binding.unbound\",
  \"user_id\": 1,
  \"device_id\": 8,
  \"binding_id\": 12,
  \"reason\": \"remote_unbind\",
  \"at\": \"2026-07-20T01:00:00.000Z\",
  \"actor_device_id\": 5,
  \"actor_device_display_name\": \"家里的手机\",
  \"actor_device_name\": \"Pixel 8 Pro\"
}
```"""
if old_ex in rt:
    rt = rt.replace(old_ex, new_ex, 1)
    readme.write_text(rt, encoding='utf-8')
    print('readme ok')
else:
    print('readme example not found (skip)')

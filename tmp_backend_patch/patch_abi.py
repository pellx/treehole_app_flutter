from pathlib import Path

p = Path('/var/www/treehole-nest/src/user/user.service.binding.ts')
text = p.read_text(encoding='utf-8')

text = text.replace(
    '      os: string | null;\n'
    '      memory: string | null;\n'
    '    }>;\n'
    '  }> {\n'
    '    const bindings = await this.bindingRepo.find({\n'
    '      where: { user_id: userId, status: In([...LIVE_STATUSES]) },',
    '      os: string | null;\n'
    '      abi: string | null;\n'
    '    }>;\n'
    '  }> {\n'
    '    const bindings = await this.bindingRepo.find({\n'
    '      where: { user_id: userId, status: In([...LIVE_STATUSES]) },',
)

text = text.replace('            memory: meta.memory,', '            abi: meta.abi,')

old_fn = '''  /** 从指纹拼出卡片展示用字段 */
  private summarizeFingerprint(fp: FingerprintEntity | undefined): {
    brand: string | null;
    model: string | null;
    os: string | null;
    memory: string | null;
  } {
    if (!fp) {
      return { brand: null, model: null, os: null, memory: null };
    }

    const platform = (fp.platform ?? '').toLowerCase();
    if (platform === 'ios') {
      const anyFp = fp as FingerprintEntity & {
        ios_model?: string | null;
        ios_model_name?: string | null;
        ios_system_name?: string | null;
        ios_system_version?: string | null;
        ios_physical_ram_size?: number | null;
      };
      const brand = 'Apple';
      const model = anyFp.ios_model_name ?? anyFp.ios_model ?? null;
      const sys = anyFp.ios_system_name ?? 'iOS';
      const ver = anyFp.ios_system_version;
      const os = ver ? `${sys} ${ver}` : sys;
      return {
        brand,
        model,
        os,
        memory: this.formatRam(anyFp.ios_physical_ram_size),
      };
    }

    const brand = fp.build_brand ?? fp.build_manufacturer ?? null;
    const model = fp.build_model ?? null;
    const release = (fp as FingerprintEntity & { version_release?: string | null })
      .version_release;
    const os = release ? `Android ${release}` : 'Android';
    const ram = (fp as FingerprintEntity & { hw_physical_ram_size?: number | null })
      .hw_physical_ram_size;
    return {
      brand,
      model,
      os,
      memory: this.formatRam(ram),
    };
  }

  private formatRam(bytes: number | null | undefined): string | null {
'''

new_fn = '''  /** 从指纹拼出卡片展示用字段 */
  private summarizeFingerprint(fp: FingerprintEntity | undefined): {
    brand: string | null;
    model: string | null;
    os: string | null;
    abi: string | null;
  } {
    if (!fp) {
      return { brand: null, model: null, os: null, abi: null };
    }

    const platform = (fp.platform ?? '').toLowerCase();
    if (platform === 'ios') {
      const anyFp = fp as FingerprintEntity & {
        ios_model?: string | null;
        ios_model_name?: string | null;
        ios_system_name?: string | null;
        ios_system_version?: string | null;
        ios_machine?: string | null;
      };
      const brand = 'Apple';
      const model = anyFp.ios_model_name ?? anyFp.ios_model ?? null;
      const sys = anyFp.ios_system_name ?? 'iOS';
      const ver = anyFp.ios_system_version;
      const os = ver ? `${sys} ${ver}` : sys;
      return {
        brand,
        model,
        os,
        abi: anyFp.ios_machine ?? null,
      };
    }

    const brand = fp.build_brand ?? fp.build_manufacturer ?? null;
    const model = fp.build_model ?? null;
    const release = (fp as FingerprintEntity & { version_release?: string | null })
      .version_release;
    const os = release ? `Android ${release}` : 'Android';
    return {
      brand,
      model,
      os,
      abi: this.formatAbi(fp),
    };
  }

  /** 取主 ABI，优先 64 位列表 */
  private formatAbi(fp: FingerprintEntity): string | null {
    const list =
      (fp.abi_supported_64bit?.length ? fp.abi_supported_64bit : null) ??
      fp.abi_supported_abis;
    if (!list || list.length === 0) return null;
    return list[0] ?? null;
  }

  private formatRam(bytes: number | null | undefined): string | null {
'''

if old_fn not in text:
    raise SystemExit('summarizeFingerprint block not found')
text = text.replace(old_fn, new_fn)
p.write_text(text, encoding='utf-8')
print('OK')

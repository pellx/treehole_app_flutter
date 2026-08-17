# Treehole Flutter — 待办与已知问题

> 最后更新：2026-07-17  
> 聚焦：Session 申请 / fingerprint_hash

---

## P0 — Session 申请阻塞

### ~~1. 客户端 fingerprint_hash 数组未排序~~ ✅ 已修复

- `_sortedJoin()` sort 后 join

### ~~2. 可变字段导致 hash 漂移~~ ✅ 客户端已修复，**待后端同步**

- 客户端 v2 仅保留 13 个 Android 硬件身份字段
- 后端须按 `advice.md` 修改 `fingerprint.ts` 并重算 DB

### 3. Session hash 策略：实时计算，不持久化 ✅

- 每次 `ensureSession()` 采集 + 计算；不写入 Keystore
- `DeviceCredentialStore.saveFingerprintHash()` 仍存在但未调用（可后续清理）

---

## P1 — 注册流程

### 4. Turnstile WebView 被注释 ✅

- **位置**：`register_page.dart` 已用 1×1 透明 `WebViewWidget` 挂回树
- **影响**：Turnstile 可正常取 token（仍需服务端校验通过）

### 5. 登录流程未实现

- **位置**：`register_page.dart` `_confirmLogin()`、`找回用户`
- **影响**：已注册设备只能看到 UI，无法通过 user_token 恢复凭证

### 6. api.md 与实现文档偏差

- **api.md 附录 C** 写「客户端不需要实现 hash」
- **实际**：`SessionService` 必须在 `session/create` 时提交 `fingerprint_hash`
- **建议**：更新 api.md，明确客户端需实现与后端一致的算法

---

## P2 — 架构 / 质量

### 7. `PostStorage.isRegistered()` 与 Keystore 凭证不同步

- Hive 布尔值与 `user_token`/`device_secret` 可能不一致（清数据、调试等）
- 建议：以 Keystore 凭证为准，或注册/登出时同步两者

### 8. Hive 帖子删除未清理缩略图/评论缓存

- 见 `AGENTS.md` 已知问题

### 9. `test/widget_test.dart` 仍为 Counter 模板

### 10. `print()` 应逐步改为 `debugPrint`

- `square_page.dart`、`post_card.dart` 等

---

## fingerprint_hash v2 字段（Session 申请）

算法：`SHA-256(field1|field2|...|fieldN)`，数组 **sort** 后用 `,` join。  
每次 `ensureSession()` 实时采集并计算，**不持久化 hash**。后端须同步，见 `advice.md`。

### Android — 参与 hash（13 项）

| # | 字段 | 来源 |
|---|---|---|
| 1–7 | `build_board/brand/device/hardware/manufacturer/model/product` | `AndroidDeviceInfo` |
| 8–10 | `abi_supported_abis/32bit/64bit` | 同上，sort 后 join |
| 11–13 | `hw_is_physical_device`, `hw_physical_ram_size`, `hw_total_disk_size` | 同上 |

### Android — 已从 hash 移除（可变）

`build_bootloader`, `build_host`, `build_tags`, `build_type`,  
`hw_is_low_ram_device`, `hw_serial_number`, `hw_system_features`

### Android — 采集但不参与 hash

`build.display/fingerprint/id/name`、全部 `version.*`、`freeDiskSize`、`availableRamSize`

### iOS — 参与 hash（9 项）

`ios_model`, `ios_model_name`, `ios_system_name`, `ios_localized_model`,  
`ios_is_physical_device`, `ios_is_ios_app_on_mac`, `ios_physical_ram_size`,  
`ios_sysname`, `ios_machine`

### iOS — 已从 hash 移除

`ios_identifier_for_vendor`, `ios_total_disk_size`, `ios_nodename`

---

## Session 申请流程（当前实现）

```
ensureSession()
  ├─ 本地有 session? → validate → 有效则返回 true
  ├─ 读 user_token + device_secret（Keystore）
  ├─ DeviceFingerprintService.collect()  ← 实时采集
  ├─ _computeFingerprintHash(fp)         ← v2 算法，不持久化
  └─ POST /user/session/create
       比对 fingerprint_hash 与注册时入库值（后端须同为 v2）
```

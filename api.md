# Treehole API

Base: `http://<host>:7300/node`

---

## 目录

- [1. GET /user/pow-challenge](#1-get-userpow-challenge)
- [2. POST /user/check](#2-post-usercheck)
- [3. POST /user/register](#3-post-userregister)
- [4. POST /user/session/create](#4-post-usersessioncreate)
- [5. POST /user/session/validate](#5-post-usersessionvalidate)
- [6. POST /user/profile](#6-post-userprofile)
- [7. POST /user/rename](#7-post-userrename)
- [8. POST /user/token/reset](#8-post-usertokenreset)
- [附录 A: 设备指纹结构](#附录-a-设备指纹结构)
- [附录 B: fingerprint_hash 计算方法](#附录-b-fingerprint_hash-计算方法)
- [附录 C: 注册流程](#附录-c-注册流程)
- [附录 D: Session 使用](#附录-d-session-使用)

---

## 1. GET /user/pow-challenge

获取一次性 PoW 挑战。

**响应** `200`

```json
{
  "challenge_id": "a1b2...",
  "challenge": "e5f6...",
  "difficulty": 21
}
```

| 字段 | 说明 |
|---|---|
| `challenge_id` | 唯一标识，后续注册时回传 |
| `challenge` | 随机串 |
| `difficulty` | 要求前导零位数 |

客户端计算：遍历 nonce 直至 `SHA-256(challenge + nonce)` 前 `difficulty` 位为零。

---

## 2. POST /user/check

查询设备指纹是否已注册。仅查询，无需 Turnstile / PoW。

**请求** `200`

```json
{
  "device_finger_print": { "platform": "android", "android": {...} }
}
```

结构见 [附录 A](#附录-a-设备指纹结构)。

**响应**

```json
{ "registered": false }
```

---

## 3. POST /user/register

创建用户。需 Turnstile + PoW。指纹冲突时返回 400。

**请求** `201`

```json
{
  "user_display_id": "昵称（1-100字符）",
  "device_finger_print": { "platform": "android", "android": {...} },
  "verification_turnstile": "Cloudflare Turnstile token",
  "verification_pow": {
    "challenge_id": "来自 pow-challenge",
    "nonce": 123456
  }
}
```

**响应**

```json
{
  "user_token": "64位hex",
  "device_secret": "64位hex"
}
```

| 字段 | 说明 |
|---|---|
| `user_token` | 用户凭证 |
| `device_secret` | 设备凭证 |

**错误**

| 状态码 | message |
|---|---|
| 400 | `该设备环境已注册` |
| 400 | `Turnstile 验证失败` |
| 400 | `PoW 验证失败` |

注册成功后会写入：
- `users` — 用户记录（`user_token`、`user_display_id`）
- `devices` — 设备记录（`device_secret_hash`、`fingerprint_hash`）
- `fingerprints` — 完整指纹字段 + `fingerprint_hash`
- `user_device_binding` — active 绑定
- `user_identifier_history` — 初始名字记录

---

## 4. POST /user/session/create

用注册凭证申请 session。

**请求** `201`

```json
{
  "user_token": "注册返回的 user_token",
  "device_secret": "注册返回的 device_secret",
  "fingerprint_hash": "当前设备指纹 SHA-256 hex"
}
```

**响应**

```json
{
  "session_id": 1,
  "session_secret": "64位hex"
}
```

**校验链路**

1. `user_token` → 查用户
2. 查 active binding → 得 `device_id`
3. 查设备记录
4. `bcrypt(device_secret + DEVICE_SECRET_HASH_KEY)` 比对 `device_secret_hash`
5. `fingerprint_hash` 比对 `fingerprints.fingerprint_hash`
6. 通过后创建 Redis session

**错误**

| 状态码 | message |
|---|---|
| 401 | `USER_NOT_FOUND` |
| 401 | `DEVICE_NOT_BOUND` |
| 401 | `DEVICE_SECRET_INVALID` |
| 401 | `FINGERPRINT_MISMATCH` |

---

## 5. POST /user/session/validate

校验 session 有效性。

**请求** `200`

```json
{
  "session_id": 1,
  "session_secret": "64位hex"
}
```

**响应**

```json
{ "valid": true, "user_id": 7 }
```

服务端从 Redis 取 `session:{id}`，比对 `SHA-256(secret)` 与存储的 hash。

**错误**

| 状态码 | message |
|---|---|
| 401 | `SESSION_INVALID` |

---

## 6. POST /user/profile

查询当前用户资料（需有效 session）。

**请求** `200`

```json
{
  "session_id": 1,
  "session_secret": "64位hex"
}
```

**响应**

```json
{
  "user_display_id": "昵称",
  "display_id_changed_at": "2026-07-01T12:00:00.000Z",
  "token_reset_at": "2026-05-01T12:00:00.000Z"
}
```

| 字段 | 说明 |
|---|---|
| `user_display_id` | 当前显示名 |
| `display_id_changed_at` | 上次改名时间；从未改过为 `null` |
| `token_reset_at` | 上次令牌重置时间；从未重置过则回退为注册时间 `created_at` |

---

## 7. POST /user/rename

改名。需有效 session。冷却期 **14 天**；名字不得被其他用户使用过（含 `user_identifier_history`）。

**请求** `200`

```json
{
  "session_id": 1,
  "session_secret": "64位hex",
  "new_name": "新昵称（1-100字符）"
}
```

**响应**

```json
{
  "user_display_id": "新昵称",
  "display_id_changed_at": "2026-07-18T04:00:00.000Z"
}
```

成功后写入：
- `users.user_display_id` + `user_display_id_changed_at`
- `user_identifier_history`（`type=display_id`）

**错误**

| 状态码 | message |
|---|---|
| 400 | `NAME_EMPTY` |
| 400 | `NAME_UNCHANGED` |
| 400 | `RENAME_TOO_FREQUENT` |
| 400 | `NAME_TAKEN` |
| 401 | `MISSING_SESSION` / `SESSION_INVALID` / `USER_NOT_FOUND` |

---

## 8. POST /user/token/reset

重置用户令牌。需有效 session，**无冷却限制**。返回新 `user_token`；旧 token 立即失效（无法再申请 session）。

**请求** `200`

```json
{
  "session_id": 1,
  "session_secret": "64位hex"
}
```

**响应**

```json
{
  "user_token": "64位hex",
  "token_reset_at": "2026-07-18T04:00:00.000Z"
}
```

成功后：
- 更新 `users.user_token`
- 写入 `user_identifier_history`（`type=user_token`，不存明文）

客户端须立即用新 token 覆盖 Keystore 中的旧值。

**错误**

| 状态码 | message |
|---|---|
| 401 | `MISSING_SESSION` / `SESSION_INVALID` / `USER_NOT_FOUND` |

---

## 附录 A: 设备指纹结构

### 顶层

```typescript
{
  platform: "android" | "ios",
  android?: AndroidFingerprint,   // platform=android 时必填
  ios?: IosFingerprint            // 暂不支持
}
```

### AndroidFingerprint

| 分组 | 字段 | 类型 |
|---|---|---|
| `build` | `board` `bootloader` `brand` `device` `display` `fingerprint` `hardware` `host` `id` `manufacturer` `model` `product` `name` `tags` `type` | `string` |
| `version` | `baseOS?` `codename` `incremental` `release` `securityPatch?` | `string` |
| | `previewSdkInt?` `sdkInt` | `number` |
| `abi` | `supported32BitAbis` `supported64BitAbis` `supportedAbis` | `string[]` |
| `hardware` | `isPhysicalDevice` `isLowRamDevice` | `boolean` |
| | `freeDiskSize` `totalDiskSize` `physicalRamSize` `availableRamSize` | `number` |
| | `serialNumber` `systemFeatures` | `string` / `string[]` |

所有字段由客户端通过 `device_info_plus` 采集后原样提交，不要自行计算 hash。

### 示例

```json
{
  "platform": "android",
  "android": {
    "build": {
      "board": "kalama",
      "brand": "google",
      "device": "husky",
      "model": "Pixel 8 Pro",
      "manufacturer": "Google",
      "product": "husky",
      "fingerprint": "google/husky/husky:14/...",
      "hardware": "qcom",
      "host": "abfarm",
      "id": "AP2A.240605.024",
      "name": "husky",
      "type": "user",
      "tags": "release-keys",
      "bootloader": "gki",
      "display": "AP2A.240605.024"
    },
    "version": {
      "baseOS": "android",
      "codename": "REL",
      "incremental": "1234567",
      "release": "14",
      "sdkInt": 34,
      "securityPatch": "2024-06-05"
    },
    "abi": {
      "supported32BitAbis": [],
      "supported64BitAbis": ["arm64-v8a"],
      "supportedAbis": ["arm64-v8a"]
    },
    "hardware": {
      "isPhysicalDevice": true,
      "isLowRamDevice": false,
      "freeDiskSize": 100000000000,
      "totalDiskSize": 128000000000,
      "physicalRamSize": 12000000000,
      "availableRamSize": 5000000000,
      "serialNumber": "unknown",
      "systemFeatures": ["android.hardware.camera"]
    }
  }
}
```

---

## 附录 B: fingerprint_hash 计算方法

服务端计算，客户端不需要实现。

### 算法

```
fingerprint_hash = SHA-256(values.join('|'))
```

### 参与字段（Android）

```
build_board
build_bootloader
build_brand
build_device
build_hardware
build_host
build_manufacturer
build_model
build_product
build_tags
build_type
abi_supported_abis           → 数组 sort 后用 ',' join
abi_supported_32bit          → 数组 sort 后用 ',' join
abi_supported_64bit          → 数组 sort 后用 ',' join
hw_is_physical_device
hw_is_low_ram_device
hw_physical_ram_size
hw_total_disk_size
hw_serial_number             → 为 null / "unknown" / 空字符串时跳过
hw_system_features           → 数组 sort 后用 ',' join
```

### 伪代码

```
input = [
  build_board, build_bootloader, build_brand, build_device,
  build_hardware, build_host, build_manufacturer, build_model,
  build_product, build_tags, build_type,
  abi_supported_abis.sort().join(','),
  abi_supported_32bit.sort().join(','),
  abi_supported_64bit.sort().join(','),
  hw_is_physical_device,
  hw_is_low_ram_device,
  hw_physical_ram_size,
  hw_total_disk_size,
  // hw_serial_number 仅当非空且非 "unknown" 时加入
  hw_system_features.sort().join(','),
]

return SHA-256(input.join('|'))
```

所有值转为字符串（`null` / `undefined` → `""`），用 `|` 拼接，最终对拼接结果取 SHA-256。

### 参与字段（iOS，暂不支持注册）

```
ios_model, ios_model_name, ios_system_name, ios_localized_model,
ios_is_physical_device, ios_is_ios_app_on_mac, ios_identifier_for_vendor,
ios_physical_ram_size, ios_total_disk_size,
ios_sysname, ios_machine, ios_nodename
```

---

## 附录 C: 注册流程

```
1. GET  /user/pow-challenge     → challenge_id, challenge
2. 计算 PoW nonce + 获取 Turnstile token
3. POST /user/check             → { registered: false }
4. POST /user/register          → user_token, device_secret
5. 保存 user_token, device_secret 到 Keystore/Keychain
```

注册时服务端返回的 `fingerprint_hash` 不需要客户端显式保存——后续调用 `/user/session/create` 时需提交同设备指纹的 hash，客户端可重新采集指纹后由服务端计算（当前未实现客户端计算接口），或由注册响应中获取并持久化。

---

## 附录 D: Session 使用

受保护接口（发帖、上传等）通过 `SessionGuard` 校验，请求 body 需附带：

```json
{
  "session_id": 1,
  "session_secret": "...",
  "...": "其他业务字段"
}
```

Session 有效期 3 天，存储在 Redis 中。同一用户/设备 24 小时内最多申请 5 次 session。

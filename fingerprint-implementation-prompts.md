# Device Fingerprint 验证系统 — 实现提示词

> 以下提示词按执行顺序排列，每条提示词对应一个独立的编码任务。
> 前置条件：数据库已由人工执行 `ALTER TABLE devices ADD COLUMN fingerprint_hash VARCHAR(64) NULL; CREATE INDEX idx_fingerprint_hash ON devices(fingerprint_hash);`

---

## 提示词 1：NestJS — DeviceEntity 新增 fingerprint_hash 字段

在 `src/user/entities/device.entity.ts` 中，给 `DeviceEntity` 新增一个字段：

```typescript
@Column({ type: 'varchar', length: 64, nullable: true, default: null })
fingerprint_hash: string;
```

放在 `device_finger_print` 字段之后。这个字段存储从不可变字段计算出的 SHA-256 哈希，用于注册时的快速查重。

---

## 提示词 2：NestJS — 创建 FingerprintService

新建文件 `src/user/fingerprint/fingerprint.service.ts`，实现以下逻辑：

### 2.1 字段分类常量

在文件中定义两个常量数组，明确列出参与计算的字段路径：

**ANDROID_IMMUTABLE_FIELDS**（不可变，用于 hash 和严格比对）：
```
build.board, build.bootloader, build.brand, build.device,
build.hardware, build.manufacturer, build.model, build.product,
build.host, build.tags, build.type,
abi.supportedAbis, abi.supported32BitAbis, abi.supported64BitAbis,
hardware.isPhysicalDevice, hardware.isLowRamDevice,
hardware.physicalRamSize, hardware.totalDiskSize,
hardware.serialNumber, hardware.systemFeatures
```

**ANDROID_MONOTONIC_FIELDS**（单调递增，只允许 ≥ 当前值）：
```
version.sdkInt, version.release, version.incremental,
version.securityPatch, version.baseOS,
build.id, build.display, build.fingerprint
```

**IOS_IMMUTABLE_FIELDS**：
```
device.model, device.modelName, device.systemName, device.localizedModel,
device.isPhysicalDevice, device.isiOSAppOnMac, device.identifierForVendor,
storage.physicalRamSize, storage.totalDiskSize,
utsname.sysname, utsname.machine, utsname.nodename
```

**IOS_MONOTONIC_FIELDS**：
```
device.systemVersion, utsname.release, utsname.version
```

### 2.2 computeHardwareHash(fingerprint) → string

- 根据 `fingerprint.platform` 选取对应的 IMMUTABLE_FIELDS 列表
- 按字段路径从 fingerprint 对象中取值，转为字符串
- 对 array 类型字段（如 supportedAbis、systemFeatures）先 `.sort().join(',')`
- 将所有值用 `|` 拼接，计算 SHA-256，返回 hex 字符串
- 如果 serialNumber 为 "unknown" 或空字符串，该字段跳过（不参与拼接）

### 2.3 extractFields(fingerprint, fieldPaths) → Record<string, any>

- 工具方法，按字段路径列表从 fingerprint 中提取 key-value
- 路径如 `build.brand` → 取 `fingerprint.android.build.brand`
- 返回扁平对象 `{ 'build.brand': 'Google', ... }`

### 2.4 checkRegistrationDuplicate(fingerprint, hash) → { duplicate: boolean, matchedDeviceId?: number }

- 用 `deviceRepo.findOne({ where: { fingerprint_hash: hash } })` 查询
- 如果没找到 → `{ duplicate: false }`
- 如果找到 → 进一步调用 extractFields 对比所有 IMMUTABLE_FIELDS：
  - 全部一致 → `{ duplicate: true, matchedDeviceId: device.device_id }`（同型号同硬件 = 同一台设备）
  - 有差异（如 serialNumber 不同）→ `{ duplicate: false }`（仅型号相同的不同设备）

### 2.5 validateForLogin(storedFingerprint, submittedFingerprint) → { valid: boolean, reason?: string }

- **第一层**：比较 `platform`，不一致 → `{ valid: false, reason: 'PLATFORM_MISMATCH' }`
- **第二层**：用 extractFields 提取双方的 IMMUTABLE_FIELDS，逐一比对：
  - 如果 stored 中某字段为 null/"unknown"（旧数据缺失），跳过该字段
  - 其他不一致 → `{ valid: false, reason: 'HARDWARE_MISMATCH' }`
- **第三层**：用 extractFields 提取双方的 MONOTONIC_FIELDS，逐一比对：
  - 数值型（sdkInt）：submitted 值 < stored 值 → 失败
  - 字符串型（release、securityPatch）：用 localeCompare 比较，submitted < stored → 失败
  - 可选字段（baseOS、previewSdkInt）：stored 为 null 时跳过
  - 失败 → `{ valid: false, reason: 'VERSION_DOWNGRADE' }`
- 全部通过 → `{ valid: true }`

### 2.6 依赖注入

```typescript
@Injectable()
export class FingerprintService {
  constructor(
    @InjectRepository(DeviceEntity)
    private readonly deviceRepo: Repository<DeviceEntity>,
  ) {}
}
```

---

## 提示词 3：NestJS — 更新 UserModule 注册 FingerprintService

在 `src/user/user.module.ts` 中：

1. 新增 import：`import { FingerprintService } from './fingerprint/fingerprint.service';`
2. 在 `TypeOrmModule.forFeature([...])` 中确认 `DeviceEntity` 已存在（已有）
3. 在 `providers` 数组中添加 `FingerprintService`
4. 在 `exports` 数组中添加 `FingerprintService`（后续其他模块可能需要）

---

## 提示词 4：NestJS — 修改 LoginDto 的 fingerprint 字段

在 `src/user/dto/login.dto.ts` 中，将：

```typescript
@IsOptional()
device_finger_print?: any;
```

改为：

```typescript
@ValidateNested()
@Type(() => DeviceFingerprintDto)
device_finger_print: DeviceFingerprintDto;
```

同时补充必要的 import：
```typescript
import { ValidateNested } from 'class-validator';
import { Type } from 'class-transformer';
import { DeviceFingerprintDto } from './fingerprint.dto';
```

---

## 提示词 5：NestJS — 修改 UserService 集成 FingerprintService

在 `src/user/user.service.ts` 中做以下修改：

### 5.1 构造函数注入

新增参数：
```typescript
private readonly fingerprintService: FingerprintService,
```

### 5.2 修改 initDevice 方法

在 PoW 验证通过后、生成 device_secret 之前，插入：

```typescript
// 计算硬件哈希并查重
const hardwareHash = this.fingerprintService.computeHardwareHash(dto.device_finger_print);
const duplicateCheck = await this.fingerprintService.checkRegistrationDuplicate(
  dto.device_finger_print,
  hardwareHash,
);
if (duplicateCheck.duplicate) {
  throw new BadRequestException('该设备已注册');
}
```

在 `deviceRepo.insert()` 的参数中增加 `fingerprint_hash: hardwareHash`。

### 5.3 修改 login 方法

在 `verifyDeviceSecret` 之后、查用户之前，插入：

```typescript
// 指纹验证
if (dto.device_finger_print && device.device_finger_print) {
  const fpResult = this.fingerprintService.validateForLogin(
    device.device_finger_print,
    dto.device_finger_print,
  );
  if (!fpResult.valid) {
    this.logger.warn(`指纹验证失败: deviceId=${device.device_id}, reason=${fpResult.reason}`);
    throw new UnauthorizedException(`FINGERPRINT_${fpResult.reason}`);
  }
}
```

在 login 方法返回之前（session 创建成功后），插入指纹更新逻辑：

```typescript
// 更新设备指纹（monotonic 字段可能已变化）
if (dto.device_finger_print) {
  await this.deviceRepo.update(device.device_id, {
    device_finger_print: JSON.parse(JSON.stringify(dto.device_finger_print)),
  });
}
```

---

## 提示词 6：NestJS — 更新 user.controller.ts 的 initDevice 方法签名

当前 initDevice 已经接受 `@Req() req: Request` 并传递 `req.ip`，无需改动 controller。

确认 `initDevice` 的调用链中 `dto.device_finger_print` 被正确传递即可。

---

## 提示词 7：Flutter — 确保登录请求携带 fingerprint

检查 Flutter 端登录 API 调用代码（在 `lib/services/api.dart` 中），确认 login 请求体中包含 `device_finger_print` 字段。

当前 Flutter 端 `DeviceFingerprintService.collect()` 已经能采集完整指纹并序列化为 JSON。需要确认：

1. 登录时调用 `DeviceFingerprintService.collect()` 获取指纹
2. 将指纹 JSON 作为 `device_finger_print` 字段加入登录请求体
3. 如果当前登录流程没有发送 fingerprint，需要补上

**注意**：Flutter 端数据模型（`lib/models/device_fingerprint.dart`）的字段结构不需要改动，与服务端 DTO 已对齐。

**可选优化**：Flutter 端的 `DeviceFingerprintService.generate()` 方法（客户端 hash）在引入服务端 hash 后不再需要用于鉴权，可以保留用于本地调试，或标记为 `@deprecated`。

---

## 提示词 8：数据库变更（人工操作）

```sql
-- 添加 fingerprint_hash 列
ALTER TABLE devices ADD COLUMN fingerprint_hash VARCHAR(64) NULL DEFAULT NULL;

-- 添加索引用于注册查重
CREATE INDEX idx_fingerprint_hash ON devices(fingerprint_hash);
```

**注意**：已有设备的 `fingerprint_hash` 为 NULL，登录时如果 stored fingerprint 存在但 hash 为 NULL，应跳过 hash 查重（向后兼容），并在下次登录时补算 hash 写入。

---

## 执行顺序建议

1. **提示词 8** → 先改数据库（你手动执行）
2. **提示词 1** → DeviceEntity 加字段
3. **提示词 2** → 创建 FingerprintService（核心逻辑）
4. **提示词 3** → UserModule 注册新 Service
5. **提示词 4** → LoginDto 强类型化
6. **提示词 5** → UserService 集成
7. **提示词 6** → 确认 Controller 无需改动
8. **提示词 7** → Flutter 端确认登录携带 fingerprint
9. `npm run build` 编译验证 → PM2 重启测试

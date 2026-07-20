-- 用户-设备绑定表：自定义设备显示名
ALTER TABLE user_device_binding
  ADD COLUMN device_display_name VARCHAR(100) NULL DEFAULT NULL
  AFTER device_id;

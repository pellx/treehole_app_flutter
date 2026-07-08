-- 重建（⚠️ 会丢数据）
DROP TABLE IF EXISTS `user_device_binding`;
DROP TABLE IF EXISTS `sessions`;
DROP TABLE IF EXISTS `user_identifier_history`;
DROP TABLE IF EXISTS `rate_limit_log`;
DROP TABLE IF EXISTS `devices`;
DROP TABLE IF EXISTS `users`;

-- ============================================
-- users
-- ============================================
CREATE TABLE `users` (
  `user_id` INT NOT NULL AUTO_INCREMENT,
  `user_display_id` VARCHAR(100) NULL,
  `user_external_token` VARCHAR(128) NULL,
  `user_display_id_changed_at` TIMESTAMP NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`user_id`),
  INDEX `idx_external_token` (`user_external_token`),
  UNIQUE INDEX `uk_external_token` (`user_external_token`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- ============================================
-- devices
-- ============================================
CREATE TABLE `devices` (
  `device_id` INT NOT NULL AUTO_INCREMENT,
  `device_secret_hash` VARCHAR(128) NOT NULL,
  `device_name` VARCHAR(50) NULL,
  `device_finger_print` JSON NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`device_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- ============================================
-- user_device_binding
-- ============================================
CREATE TABLE `user_device_binding` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `user_id` INT NOT NULL,
  `device_id` INT NOT NULL,
  `status` VARCHAR(20) NOT NULL DEFAULT 'active',
  `bound_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `unbind_requested_at` TIMESTAMP NULL,
  `unbound_at` TIMESTAMP NULL,
  PRIMARY KEY (`id`),
  UNIQUE INDEX `uk_user_device` (`user_id`, `device_id`),
  INDEX `idx_device_id` (`device_id`),
  CONSTRAINT `fk_binding_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE,
  CONSTRAINT `fk_binding_device` FOREIGN KEY (`device_id`) REFERENCES `devices` (`device_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- ============================================
-- sessions
-- ============================================
CREATE TABLE `sessions` (
  `session_id` INT NOT NULL AUTO_INCREMENT,
  `session_secret_hash` VARCHAR(128) NOT NULL,
  `user_id` INT NOT NULL,
  `device_id` INT NOT NULL,
  `expires_at` TIMESTAMP NOT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`session_id`),
  INDEX `idx_user_id` (`user_id`),
  INDEX `idx_device_id` (`device_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- ============================================
-- user_identifier_history
-- ============================================
CREATE TABLE `user_identifier_history` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `user_id` INT NOT NULL,
  `type` VARCHAR(20) NOT NULL,
  `old_value` VARCHAR(255) NULL,
  `changed_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  INDEX `idx_user_id_type` (`user_id`, `type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- ============================================
-- rate_limit_log
-- ============================================
CREATE TABLE `rate_limit_log` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `subject_type` VARCHAR(10) NOT NULL,
  `subject_id` VARCHAR(64) NOT NULL,
  `action` VARCHAR(30) NOT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  INDEX `idx_subject_action_time` (`subject_type`, `subject_id`, `action`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

GRANT SELECT, INSERT, UPDATE, DELETE ON treehole_post.users TO 'submit-post'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE ON treehole_post.devices TO 'submit-post'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE ON treehole_post.user_device_binding TO 'submit-post'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE ON treehole_post.sessions TO 'submit-post'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE ON treehole_post.user_identifier_history TO 'submit-post'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE ON treehole_post.rate_limit_log TO 'submit-post'@'localhost';
FLUSH PRIVILEGES;

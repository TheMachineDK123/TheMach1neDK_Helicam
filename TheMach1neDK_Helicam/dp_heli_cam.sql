CREATE TABLE IF NOT EXISTS `dp_heli_cam_anpr` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `officer_identifier` VARCHAR(64) NOT NULL,
  `plate` VARCHAR(16) NOT NULL,
  `model` VARCHAR(64) NOT NULL,
  `speed` INT NOT NULL DEFAULT 0,
  `gps_x` DOUBLE NOT NULL DEFAULT 0,
  `gps_y` DOUBLE NOT NULL DEFAULT 0,
  `distance` DOUBLE NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_plate` (`plate`),
  KEY `idx_officer_identifier` (`officer_identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

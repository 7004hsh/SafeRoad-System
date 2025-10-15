-- -----------------------------------------------------
--  TeamRoute 데이터베이스 스키마 (2025-10-15)
--  IntelliJ IDEA Database Tools에서 바로 실행할 수 있도록 구성된 DDL 스크립트입니다.
-- -----------------------------------------------------

-- 데이터베이스 생성 및 사용 (필요시 데이터베이스명을 수정하세요)
CREATE DATABASE IF NOT EXISTS `teamroute`
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_general_ci;
USE `teamroute`;

-- 안전하게 재생성할 수 있도록 기존 객체 제거
DROP VIEW IF EXISTS `V_OBSTACLE_OVERVIEW`;
DROP VIEW IF EXISTS `V_OBSTACLE_WITH_USER`;
DROP TABLE IF EXISTS `ObstacleAdminMemo`;
DROP TABLE IF EXISTS `ObstacleStatusHistory`;
DROP TABLE IF EXISTS `ObstacleAttachment`;
DROP TABLE IF EXISTS `UserObstacleBookmark`;
DROP TABLE IF EXISTS `Obstacle`;
DROP TABLE IF EXISTS `ObstacleCategory`;
DROP TABLE IF EXISTS `SocialUserAccount`;
DROP TABLE IF EXISTS `User`;

-- 사용자 기본 정보 테이블
CREATE TABLE `User` (
  `id`              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '사용자 식별자',
  `login_id`        VARCHAR(50)     NOT NULL COMMENT '로그인용 아이디',
  `password_hash`   VARCHAR(255)    NOT NULL COMMENT '암호화된 비밀번호',
  `name`            VARCHAR(100)    NULL COMMENT '사용자 이름',
  `nickname`        VARCHAR(50)     NULL COMMENT '표시용 닉네임',
  `phone_number`    VARCHAR(20)     NULL COMMENT '휴대전화 번호',
  `email`           VARCHAR(255)    NULL COMMENT '연락 이메일',
  `email_opt_in`    TINYINT(1)      NOT NULL DEFAULT 0 COMMENT '이메일 수신 여부',
  `sms_opt_in`      TINYINT(1)      NOT NULL DEFAULT 0 COMMENT 'SMS 수신 여부',
  `birth_date`      DATE            NULL COMMENT '생년월일',
  `gender`          ENUM('none', 'male', 'female') NOT NULL DEFAULT 'none' COMMENT '성별',
  `role`            ENUM('user', 'admin') NOT NULL DEFAULT 'user' COMMENT '권한 구분',
  `status`          ENUM('active', 'suspended', 'deleted') NOT NULL DEFAULT 'active' COMMENT '계정 상태',
  `last_login_at`   DATETIME(6)     NULL COMMENT '마지막 로그인 일시',
  `created_at`      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '생성 일시',
  `updated_at`      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '수정 일시',
  CONSTRAINT `PK_USER` PRIMARY KEY (`id`),
  CONSTRAINT `UK_USER_LOGIN_ID` UNIQUE (`login_id`),
  CONSTRAINT `UK_USER_EMAIL` UNIQUE (`email`)
) COMMENT='회원 기본 정보';

-- 소셜 연동 계정
CREATE TABLE `SocialUserAccount` (
  `id`               BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '소셜 계정 식별자',
  `user_id`          BIGINT UNSIGNED NOT NULL COMMENT '연동된 사용자 id',
  `provider`         VARCHAR(50)     NOT NULL COMMENT '소셜 제공자 (kakao, naver, google 등)',
  `provider_user_id` VARCHAR(255)    NOT NULL COMMENT '소셜 내 사용자 식별값',
  `email`            VARCHAR(255)    NULL COMMENT '소셜 이메일',
  `display_name`     VARCHAR(100)    NULL COMMENT '소셜 표시 이름',
  `connected_at`     DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '연동 일시',
  `revoked_at`       DATETIME(6)     NULL COMMENT '연동 해제 일시',
  CONSTRAINT `PK_SOCIAL_USER_ACCOUNT` PRIMARY KEY (`id`),
  CONSTRAINT `FK_SOCIAL_USER_ACCOUNT_USER` FOREIGN KEY (`user_id`) REFERENCES `User`(`id`) ON DELETE CASCADE,
  CONSTRAINT `UK_SOCIAL_PROVIDER_USER` UNIQUE (`provider`, `provider_user_id`)
) COMMENT='소셜 로그인 연동 정보';

-- 장애물 분류 코드
CREATE TABLE `ObstacleCategory` (
  `id`            TINYINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '카테고리 식별자',
  `category_code` VARCHAR(30)      NOT NULL COMMENT '카테고리 코드',
  `category_name` VARCHAR(100)     NOT NULL COMMENT '카테고리 명칭',
  `description`   VARCHAR(255)     NULL COMMENT '설명',
  `display_order` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '표시 순서',
  `is_active`     TINYINT(1)       NOT NULL DEFAULT 1 COMMENT '사용 여부',
  `created_at`    DATETIME(6)      NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '생성 일시',
  `updated_at`    DATETIME(6)      NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '수정 일시',
  CONSTRAINT `PK_OBSTACLE_CATEGORY` PRIMARY KEY (`id`),
  CONSTRAINT `UK_OBSTACLE_CATEGORY_CODE` UNIQUE (`category_code`)
) COMMENT='장애물 분류 코드';

-- 기본 장애물 분류 데이터
INSERT INTO `ObstacleCategory` (`category_code`, `category_name`, `description`, `display_order`)
VALUES
  ('surface', '노면 이상', '포트홀, 요철 등 도로 표면 손상', 1),
  ('facility', '도로 시설물 장애', '휠체어 경사로, 점자블록 등 시설물 훼손', 2),
  ('parking', '불법 주정차', '보행 장애를 유발하는 불법 주정차', 3),
  ('etc', '기타', '기타 장애 요소', 4)
ON DUPLICATE KEY UPDATE
  `category_name` = VALUES(`category_name`),
  `description`   = VALUES(`description`),
  `display_order` = VALUES(`display_order`),
  `is_active`     = 1;

-- 장애물 제보 정보
CREATE TABLE `Obstacle` (
  `id`               BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '장애물 식별자',
  `reporter_id`      BIGINT UNSIGNED NOT NULL COMMENT '제보한 사용자 id',
  `category_id`      TINYINT UNSIGNED NULL COMMENT '장애물 카테고리',
  `title`            VARCHAR(150)    NOT NULL COMMENT '장애물 제목',
  `description`      TEXT            NULL COMMENT '상세 설명',
  `latitude`         DECIMAL(10,7)   NOT NULL COMMENT '위도',
  `longitude`        DECIMAL(10,7)   NOT NULL COMMENT '경도',
  `road_address`     VARCHAR(255)    NULL COMMENT '도로명 주소',
  `detail_address`   VARCHAR(255)    NULL COMMENT '상세 위치 설명',
  `detected_at`      DATETIME(6)     NULL COMMENT '장애물 최초 인지 일시',
  `status`           ENUM('reported', 'in_progress', 'resolved', 'rejected') NOT NULL DEFAULT 'reported' COMMENT '처리 상태',
  `severity`         ENUM('low', 'medium', 'high') NOT NULL DEFAULT 'low' COMMENT '위험도',
  `view_count`       INT UNSIGNED    NOT NULL DEFAULT 0 COMMENT '조회수',
  `bookmark_count`   INT UNSIGNED    NOT NULL DEFAULT 0 COMMENT '즐겨찾기 수',
  `resolved_at`      DATETIME(6)     NULL COMMENT '처리 완료 일시',
  `rejected_reason`  VARCHAR(255)    NULL COMMENT '반려 사유',
  `created_at`       DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '등록 일시',
  `updated_at`       DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '갱신 일시',
  CONSTRAINT `PK_OBSTACLE` PRIMARY KEY (`id`),
  CONSTRAINT `FK_OBSTACLE_REPORTER` FOREIGN KEY (`reporter_id`) REFERENCES `User`(`id`) ON DELETE CASCADE,
  CONSTRAINT `FK_OBSTACLE_CATEGORY` FOREIGN KEY (`category_id`) REFERENCES `ObstacleCategory`(`id`) ON DELETE SET NULL,
  INDEX `IDX_OBSTACLE_REPORTER` (`reporter_id`),
  INDEX `IDX_OBSTACLE_STATUS` (`status`),
  INDEX `IDX_OBSTACLE_CATEGORY` (`category_id`),
  INDEX `IDX_OBSTACLE_LOCATION` (`latitude`, `longitude`)
) COMMENT='사용자 장애물 제보 정보';

-- 장애물 첨부 자료 (사진, 영상 등)
CREATE TABLE `ObstacleAttachment` (
  `id`          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '첨부 식별자',
  `obstacle_id` BIGINT UNSIGNED NOT NULL COMMENT '장애물 id',
  `file_type`   ENUM('image', 'video') NOT NULL DEFAULT 'image' COMMENT '파일 종류',
  `file_url`    VARCHAR(500)    NOT NULL COMMENT '저장 경로',
  `thumbnail_url` VARCHAR(500)  NULL COMMENT '썸네일 경로',
  `sort_order`  TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT '노출 순서',
  `created_at`  DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '등록 일시',
  CONSTRAINT `PK_OBSTACLE_ATTACHMENT` PRIMARY KEY (`id`),
  CONSTRAINT `FK_OBSTACLE_ATTACHMENT_OBSTACLE` FOREIGN KEY (`obstacle_id`) REFERENCES `Obstacle`(`id`) ON DELETE CASCADE,
  INDEX `IDX_OBSTACLE_ATTACHMENT_OBS` (`obstacle_id`)
) COMMENT='장애물 첨부 자료';

-- 장애물 상태 이력 (관리자 처리 로그)
CREATE TABLE `ObstacleStatusHistory` (
  `id`            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '히스토리 식별자',
  `obstacle_id`   BIGINT UNSIGNED NOT NULL COMMENT '대상 장애물 id',
  `changed_by`    BIGINT UNSIGNED NULL COMMENT '상태 변경자 (관리자)',
  `prev_status`   ENUM('reported', 'in_progress', 'resolved', 'rejected') NOT NULL COMMENT '변경 전 상태',
  `new_status`    ENUM('reported', 'in_progress', 'resolved', 'rejected') NOT NULL COMMENT '변경 후 상태',
  `memo`          VARCHAR(500)    NULL COMMENT '변경 메모',
  `created_at`    DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '변경 일시',
  CONSTRAINT `PK_OBSTACLE_STATUS_HISTORY` PRIMARY KEY (`id`),
  CONSTRAINT `FK_OBSTACLE_STATUS_HISTORY_OBS` FOREIGN KEY (`obstacle_id`) REFERENCES `Obstacle`(`id`) ON DELETE CASCADE,
  CONSTRAINT `FK_OBSTACLE_STATUS_HISTORY_USER` FOREIGN KEY (`changed_by`) REFERENCES `User`(`id`) ON DELETE SET NULL,
  INDEX `IDX_OBS_HISTORY_OBS` (`obstacle_id`)
) COMMENT='장애물 상태 변경 로그';

-- 장애물 관리자 메모 (고도화된 처리 내역)
CREATE TABLE `ObstacleAdminMemo` (
  `id`          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '메모 식별자',
  `obstacle_id` BIGINT UNSIGNED NOT NULL COMMENT '장애물 id',
  `admin_id`    BIGINT UNSIGNED NOT NULL COMMENT '관리자 사용자 id',
  `memo`        TEXT            NOT NULL COMMENT '처리 내용',
  `created_at`  DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '작성 일시',
  CONSTRAINT `PK_OBSTACLE_ADMIN_MEMO` PRIMARY KEY (`id`),
  CONSTRAINT `FK_OBSTACLE_ADMIN_MEMO_OBS` FOREIGN KEY (`obstacle_id`) REFERENCES `Obstacle`(`id`) ON DELETE CASCADE,
  CONSTRAINT `FK_OBSTACLE_ADMIN_MEMO_ADMIN` FOREIGN KEY (`admin_id`) REFERENCES `User`(`id`) ON DELETE CASCADE,
  INDEX `IDX_OBS_ADMIN_MEMO_OBS` (`obstacle_id`)
) COMMENT='관리자 장애물 처리 메모';

-- 사용자 즐겨찾기 장애물
CREATE TABLE `UserObstacleBookmark` (
  `user_id`     BIGINT UNSIGNED NOT NULL,
  `obstacle_id` BIGINT UNSIGNED NOT NULL,
  `created_at`  DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '등록 일시',
  CONSTRAINT `PK_USER_OBSTACLE_BOOKMARK` PRIMARY KEY (`user_id`, `obstacle_id`),
  CONSTRAINT `FK_BOOKMARK_USER` FOREIGN KEY (`user_id`) REFERENCES `User`(`id`) ON DELETE CASCADE,
  CONSTRAINT `FK_BOOKMARK_OBSTACLE` FOREIGN KEY (`obstacle_id`) REFERENCES `Obstacle`(`id`) ON DELETE CASCADE
) COMMENT='사용자 장애물 즐겨찾기';

-- 장애물과 제보자 정보를 함께 조회하는 뷰
CREATE OR REPLACE VIEW `V_OBSTACLE_WITH_USER` AS
SELECT
  o.id,
  o.title,
  o.description,
  o.latitude,
  o.longitude,
  o.status,
  o.severity,
  o.road_address,
  o.detail_address,
  o.created_at,
  o.updated_at,
  u.login_id    AS reporter_login_id,
  u.name        AS reporter_name,
  u.email       AS reporter_email,
  c.category_name,
  c.category_code
FROM `Obstacle` o
JOIN `User` u ON u.id = o.reporter_id
LEFT JOIN `ObstacleCategory` c ON c.id = o.category_id;

-- 장애물 개요를 위한 뷰 (관리자 대시보드용)
CREATE OR REPLACE VIEW `V_OBSTACLE_OVERVIEW` AS
SELECT
  o.id,
  o.title,
  o.status,
  o.severity,
  o.created_at,
  o.updated_at,
  o.resolved_at,
  u.login_id AS reporter_login_id,
  ac.login_id AS admin_login_id,
  c.category_name,
  h.new_status,
  h.memo AS last_admin_memo,
  h.created_at AS last_action_at
FROM `Obstacle` o
JOIN `User` u ON u.id = o.reporter_id
LEFT JOIN (
  SELECT h1.obstacle_id,
         h1.changed_by,
         h1.new_status,
         h1.memo,
         h1.created_at
  FROM `ObstacleStatusHistory` h1
  JOIN (
    SELECT obstacle_id, MAX(created_at) AS max_created_at
    FROM `ObstacleStatusHistory`
    GROUP BY obstacle_id
  ) latest ON latest.obstacle_id = h1.obstacle_id
           AND latest.max_created_at = h1.created_at
) h ON h.obstacle_id = o.id
LEFT JOIN `User` ac ON ac.id = h.changed_by
LEFT JOIN `ObstacleCategory` c ON c.id = o.category_id;

-- 조회 성능 향상을 위한 보조 인덱스
CREATE INDEX `IDX_SOCIAL_USER_ID` ON `SocialUserAccount` (`user_id`);
CREATE INDEX `IDX_OBSTACLE_CREATED_AT` ON `Obstacle` (`created_at`);
CREATE INDEX `IDX_OBSTACLE_STATUS_CREATED` ON `Obstacle` (`status`, `created_at`);

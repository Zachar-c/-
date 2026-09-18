-- fortune-app 数据库建表脚本
-- H2 数据库（兼容 MySQL / PostgreSQL 语法）
-- 表结构由 FortuneRepository.initSchema() 自动创建，
-- 此文件仅作为文档参考，运行时不需要。

CREATE TABLE IF NOT EXISTS fortunes (
    id INT PRIMARY KEY AUTO_INCREMENT,
    text VARCHAR(500) NOT NULL,
    level INT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

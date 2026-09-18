package com.example.config;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.Properties;

public class AppConfig {
    private static final Logger logger = LoggerFactory.getLogger(AppConfig.class);
    private static final String CONFIG_FILE = "application.properties";
    private final Properties properties = new Properties();

    public AppConfig() {
        load();
    }

    public AppConfig(int port, String dataFile) {
        properties.setProperty("server.port", String.valueOf(port));
    }

    public AppConfig(int port, String dataFile, String dbUrl, String dbUsername, String dbPassword) {
        properties.setProperty("server.port", String.valueOf(port));
        properties.setProperty("fortune.db.url", dbUrl);
        properties.setProperty("fortune.db.username", dbUsername);
        properties.setProperty("fortune.db.password", dbPassword);
    }

    private void load() {
        // 1. 加载 classpath 内置配置
        try (InputStream input = getClass().getClassLoader().getResourceAsStream(CONFIG_FILE)) {
            if (input != null) {
                properties.load(input);
            }
        } catch (IOException e) {
            logger.warn("⚠️ 加载内置配置失败：{}", e.getMessage());
        }

        // 2. 外部配置覆盖内置配置
        Path externalPath = Paths.get(CONFIG_FILE);
        if (Files.exists(externalPath)) {
            try (InputStream input = Files.newInputStream(externalPath)) {
                Properties external = new Properties();
                external.load(input);
                properties.putAll(external);
                logger.info("📄 已加载外部配置：{}", externalPath.toAbsolutePath());
            } catch (IOException e) {
                logger.warn("⚠️ 加载外部配置失败：{}", e.getMessage());
            }
        }
    }

    public int getServerPort() {
        String port = properties.getProperty("server.port", "8080");
        try {
            return Integer.parseInt(port);
        } catch (NumberFormatException e) {
            logger.warn("⚠️ 端口配置无效，使用默认值 8080");
            return 8080;
        }
    }

    public String getDbUrl() {
        return properties.getProperty("fortune.db.url", "jdbc:h2:file:./data/fortune-db");
    }

    public String getDbUsername() {
        return properties.getProperty("fortune.db.username", "sa");
    }

    public String getDbPassword() {
        return properties.getProperty("fortune.db.password", "");
    }
}

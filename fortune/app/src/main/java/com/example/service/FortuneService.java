package com.example.service;

import com.example.config.AppConfig;
import com.example.model.Fortune;
import com.example.repository.FortuneRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.Random;
import java.util.stream.Collectors;

public class FortuneService {
    private static final Logger logger = LoggerFactory.getLogger(FortuneService.class);
    private static final String CLASSPATH_FILE = "/fortunes.txt";
    private static final String SEPARATOR = "\\|";

    private final FortuneRepository repository;
    private final Random random = new Random();

    public FortuneService(AppConfig config) {
        this.repository = new FortuneRepository(config);
        if (repository.isEmpty()) {
            seedFromClasspath();
        }
    }

    private void seedFromClasspath() {
        try (InputStream input = getClass().getResourceAsStream(CLASSPATH_FILE)) {
            if (input == null) {
                logger.warn("⚠️ 未找到 classpath 种子数据 {}", CLASSPATH_FILE);
                return;
            }
            try (BufferedReader reader = new BufferedReader(new InputStreamReader(input, StandardCharsets.UTF_8))) {
                List<Fortune> loaded = reader.lines()
                        .map(this::parseLine)
                        .filter(f -> f != null)
                        .collect(Collectors.toList());
                if (loaded.isEmpty()) {
                    logger.warn("⚠️ 种子数据文件为空");
                    return;
                }
                repository.seed(loaded);
            }
        } catch (IOException e) {
            logger.error("❌ 读取种子数据失败：{}", e.getMessage(), e);
        }
    }

    private Fortune parseLine(String line) {
        line = line.trim();
        if (line.isEmpty()) {
            return null;
        }
        String[] parts = line.split(SEPARATOR, 2);
        if (parts.length != 2) {
            logger.warn("⚠️ 种子数据格式错误，已跳过：{}", line);
            return null;
        }
        try {
            int level = Integer.parseInt(parts[1].trim());
            return new Fortune(parts[0].trim(), level);
        } catch (NumberFormatException e) {
            logger.warn("⚠️ 种子数据星级不是数字，已跳过：{}", line);
            return null;
        }
    }

    public Fortune getRandomFortune() {
        List<Fortune> all = repository.findAll();
        if (all.isEmpty()) {
            return null;
        }
        return all.get(random.nextInt(all.size()));
    }

    public List<Fortune> getAllFortunes() {
        return repository.findAll();
    }

    public int getFortuneCount() {
        return repository.count();
    }

    public List<Fortune> getFortunesByLevel(int level) {
        return repository.findByLevel(level);
    }

    public Fortune getFortuneById(int id) {
        // API id 从 0 开始，数据库 id 从 1 开始
        return repository.findById(id + 1);
    }

    public synchronized boolean addFortune(String text, int level) {
        if (text == null || text.trim().isEmpty()) {
            return false;
        }
        if (level < 1 || level > 6) {
            return false;
        }
        int newId = repository.insert(text.trim(), level);
        if (newId > 0) {
            logger.info("➕ 新增运势 id={}：{} | {}", newId, text.trim(), level);
            return true;
        }
        return false;
    }

    void clearAll() {
        repository.deleteAll();
    }

    public synchronized boolean deleteFortune(int id) {
        // API id 从 0 开始，数据库 id 从 1 开始
        boolean success = repository.delete(id + 1);
        if (success) {
            logger.info("🗑️ 删除运势 id={}", id);
            return true;
        }
        return false;
    }
}

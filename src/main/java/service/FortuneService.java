package com.example.service;

import com.example.model.Fortune;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import java.util.Random;
import java.util.stream.Collectors;

public class FortuneService {
    private static final String FILE_NAME = "/fortunes.txt";
    private static final String SEPARATOR = "\\|";

    private final List<Fortune> fortunes;
    private final Random random = new Random();

    public FortuneService() {
        this.fortunes = loadFortunes();
    }

    private List<Fortune> loadFortunes() {
        InputStream input = getClass().getResourceAsStream(FILE_NAME);
        if (input == null) {
            System.out.println("⚠️ 未找到 classpath 资源 " + FILE_NAME + "，使用默认运势");
            return defaultFortunes();
        }

        List<Fortune> loaded = new ArrayList<>();
        try (BufferedReader reader = new BufferedReader(new InputStreamReader(input, StandardCharsets.UTF_8))) {
            String line;
            int lineNumber = 0;
            while ((line = reader.readLine()) != null) {
                lineNumber++;
                line = line.trim();
                if (line.isEmpty()) {
                    continue;
                }
                String[] parts = line.split(SEPARATOR, 2);
                if (parts.length != 2) {
                    System.out.println("⚠️ 第 " + lineNumber + " 行格式错误，已跳过：" + line);
                    continue;
                }
                try {
                    int level = Integer.parseInt(parts[1].trim());
                    loaded.add(new Fortune(parts[0].trim(), level));
                } catch (NumberFormatException e) {
                    System.out.println("⚠️ 第 " + lineNumber + " 行星級不是数字，已跳过：" + line);
                }
            }
        } catch (IOException e) {
            System.out.println("⚠️ 读取 " + FILE_NAME + " 失败：" + e.getMessage());
        }

        if (loaded.isEmpty()) {
            System.out.println("⚠️ " + FILE_NAME + " 中没有有效数据，使用默认运势");
            return defaultFortunes();
        }
        return loaded;
    }

    private List<Fortune> defaultFortunes() {
        return List.of(
            new Fortune("大吉：默认运势，一切都会好起来的", 5),
            new Fortune("中吉：保持平常心", 3)
        );
    }

    public Fortune getRandomFortune() {
        return fortunes.get(random.nextInt(fortunes.size()));
    }

    public List<Fortune> getAllFortunes() {
        return fortunes;
    }

    public int getFortuneCount() {
        return fortunes.size();
    }

    public List<Fortune> getFortunesByLevel(int level) {
        return fortunes.stream()
                .filter(f -> f.getLevel() == level)
                .collect(Collectors.toList());
    }

    public Fortune getFortuneById(int id) {
        if (id < 0 || id >= fortunes.size()) {
            return null;
        }
        return fortunes.get(id);
    }
}

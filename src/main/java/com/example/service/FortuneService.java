package com.example.service;

import com.example.config.AppConfig;
import com.example.model.Fortune;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.List;
import java.util.Random;
import java.util.stream.Collectors;

public class FortuneService {
    private static final String CLASSPATH_FILE = "/fortunes.txt";
    private static final String SEPARATOR = "\\|";

    private final List<Fortune> fortunes;
    private final Path externalPath;
    private final Random random = new Random();

    public FortuneService(AppConfig config) {
        this.externalPath = Paths.get(config.getFortuneDataFile());
        this.fortunes = loadFortunes();
    }

    private List<Fortune> loadFortunes() {
        InputStream input = null;
        try {
            if (Files.exists(externalPath)) {
                System.out.println("📂 从外部文件加载运势：" + externalPath.toAbsolutePath());
                return readFromReader(Files.newBufferedReader(externalPath, StandardCharsets.UTF_8));
            }

            input = getClass().getResourceAsStream(CLASSPATH_FILE);
            if (input == null) {
                System.out.println("⚠️ 未找到 classpath 资源 " + CLASSPATH_FILE + "，使用默认运势");
                return defaultFortunes();
            }
            System.out.println("📦 从 classpath 加载运势，并复制到外部文件");
            List<Fortune> loaded = readFromReader(new BufferedReader(new InputStreamReader(input, StandardCharsets.UTF_8)));
            saveFortunes(loaded);
            return loaded;
        } catch (IOException e) {
            System.out.println("⚠️ 读取运势失败：" + e.getMessage());
            return defaultFortunes();
        } finally {
            if (input != null) {
                try {
                    input.close();
                } catch (IOException ignored) {
                }
            }
        }
    }

    private List<Fortune> readFromReader(BufferedReader reader) throws IOException {
        List<Fortune> loaded = new ArrayList<>();
        try (reader) {
            String line;
            int lineNumber = 0;
            while ((line = reader.readLine()) != null) {
                lineNumber++;
                Fortune fortune = parseLine(line, lineNumber);
                if (fortune != null) {
                    loaded.add(fortune);
                }
            }
        }

        if (loaded.isEmpty()) {
            System.out.println("⚠️ 数据文件中没有有效数据，使用默认运势");
            return defaultFortunes();
        }
        return loaded;
    }

    private Fortune parseLine(String line, int lineNumber) {
        line = line.trim();
        if (line.isEmpty()) {
            return null;
        }
        String[] parts = line.split(SEPARATOR, 2);
        if (parts.length != 2) {
            System.out.println("⚠️ 第 " + lineNumber + " 行格式错误，已跳过：" + line);
            return null;
        }
        try {
            int level = Integer.parseInt(parts[1].trim());
            return new Fortune(parts[0].trim(), level);
        } catch (NumberFormatException e) {
            System.out.println("⚠️ 第 " + lineNumber + " 行星級不是数字，已跳过：" + line);
            return null;
        }
    }

    private synchronized void saveFortunes(List<Fortune> fortunesToSave) {
        try {
            Files.createDirectories(externalPath.getParent());
            List<String> lines = fortunesToSave.stream()
                    .map(f -> f.getText() + "|" + f.getLevel())
                    .collect(Collectors.toList());
            Files.write(externalPath, lines, StandardCharsets.UTF_8);
        } catch (IOException e) {
            System.out.println("⚠️ 保存运势失败：" + e.getMessage());
        }
    }

    private List<Fortune> defaultFortunes() {
        return new ArrayList<>(List.of(
            new Fortune("大吉：默认运势，一切都会好起来的", 5),
            new Fortune("中吉：保持平常心", 3)
        ));
    }

    public Fortune getRandomFortune() {
        return fortunes.get(random.nextInt(fortunes.size()));
    }

    public List<Fortune> getAllFortunes() {
        return new ArrayList<>(fortunes);
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

    public synchronized boolean addFortune(String text, int level) {
        if (text == null || text.trim().isEmpty()) {
            return false;
        }
        if (level < 1 || level > 6) {
            return false;
        }
        fortunes.add(new Fortune(text.trim(), level));
        saveFortunes(fortunes);
        return true;
    }

    public synchronized boolean deleteFortune(int id) {
        if (id < 0 || id >= fortunes.size()) {
            return false;
        }
        fortunes.remove(id);
        saveFortunes(fortunes);
        return true;
    }
}

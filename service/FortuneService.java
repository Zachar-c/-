package service;

import model.Fortune;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.List;
import java.util.Random;
import java.util.stream.Collectors;

public class FortuneService {
    private static final String FILE_NAME = "fortunes.txt";
    private static final String SEPARATOR = "\\|";

    private final List<Fortune> fortunes;
    private final Random random = new Random();

    public FortuneService() {
        this.fortunes = loadFortunes();
    }

    private List<Fortune> loadFortunes() {
        Path path = Paths.get(FILE_NAME);
        if (!Files.exists(path)) {
            System.out.println("⚠️ 未找到 " + FILE_NAME + "，使用默认运势");
            return defaultFortunes();
        }

        List<Fortune> loaded = new ArrayList<>();
        try {
            List<String> lines = Files.readAllLines(path);
            for (int i = 0; i < lines.size(); i++) {
                String line = lines.get(i).trim();
                if (line.isEmpty()) {
                    continue;
                }
                String[] parts = line.split(SEPARATOR, 2);
                if (parts.length != 2) {
                    System.out.println("⚠️ 第 " + (i + 1) + " 行格式错误，已跳过：" + line);
                    continue;
                }
                try {
                    int level = Integer.parseInt(parts[1].trim());
                    loaded.add(new Fortune(parts[0].trim(), level));
                } catch (NumberFormatException e) {
                    System.out.println("⚠️ 第 " + (i + 1) + " 行星级不是数字，已跳过：" + line);
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

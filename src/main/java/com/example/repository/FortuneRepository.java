package com.example.repository;

import com.example.config.AppConfig;
import com.example.model.Fortune;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.sql.*;
import java.util.ArrayList;
import java.util.List;

public class FortuneRepository {
    private static final Logger logger = LoggerFactory.getLogger(FortuneRepository.class);

    private final String url;
    private final String username;
    private final String password;

    public FortuneRepository(AppConfig config) {
        this.url = config.getDbUrl();
        this.username = config.getDbUsername();
        this.password = config.getDbPassword();
        initSchema();
    }

    private Connection getConnection() throws SQLException {
        return DriverManager.getConnection(url, username, password);
    }

    private void initSchema() {
        try (Connection conn = getConnection();
             Statement stmt = conn.createStatement()) {
            stmt.execute(
                "CREATE TABLE IF NOT EXISTS fortunes (" +
                "id INT PRIMARY KEY AUTO_INCREMENT, " +
                "text VARCHAR(500) NOT NULL, " +
                "level INT NOT NULL, " +
                "created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP" +
                ")"
            );
            logger.info("✅ 数据库表初始化完成");
        } catch (SQLException e) {
            logger.error("❌ 数据库表初始化失败：{}", e.getMessage(), e);
        }
    }

    public List<Fortune> findAll() {
        List<Fortune> list = new ArrayList<>();
        String sql = "SELECT text, level FROM fortunes ORDER BY id";
        try (Connection conn = getConnection();
             Statement stmt = conn.createStatement();
             ResultSet rs = stmt.executeQuery(sql)) {
            while (rs.next()) {
                list.add(new Fortune(rs.getString("text"), rs.getInt("level")));
            }
        } catch (SQLException e) {
            logger.error("❌ 查询全部运势失败：{}", e.getMessage(), e);
        }
        return list;
    }

    public Fortune findById(int id) {
        String sql = "SELECT text, level FROM fortunes WHERE id = ?";
        try (Connection conn = getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setInt(1, id);
            try (ResultSet rs = stmt.executeQuery()) {
                if (rs.next()) {
                    return new Fortune(rs.getString("text"), rs.getInt("level"));
                }
            }
        } catch (SQLException e) {
            logger.error("❌ 按 id 查询失败：{}", e.getMessage(), e);
        }
        return null;
    }

    public List<Fortune> findByLevel(int level) {
        List<Fortune> list = new ArrayList<>();
        String sql = "SELECT text, level FROM fortunes WHERE level = ? ORDER BY id";
        try (Connection conn = getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setInt(1, level);
            try (ResultSet rs = stmt.executeQuery()) {
                while (rs.next()) {
                    list.add(new Fortune(rs.getString("text"), rs.getInt("level")));
                }
            }
        } catch (SQLException e) {
            logger.error("❌ 按星级查询失败：{}", e.getMessage(), e);
        }
        return list;
    }

    public int count() {
        String sql = "SELECT COUNT(*) FROM fortunes";
        try (Connection conn = getConnection();
             Statement stmt = conn.createStatement();
             ResultSet rs = stmt.executeQuery(sql)) {
            if (rs.next()) {
                return rs.getInt(1);
            }
        } catch (SQLException e) {
            logger.error("❌ 计数失败：{}", e.getMessage(), e);
        }
        return 0;
    }

    public int insert(String text, int level) {
        String sql = "INSERT INTO fortunes (text, level) VALUES (?, ?)";
        try (Connection conn = getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql, Statement.RETURN_GENERATED_KEYS)) {
            stmt.setString(1, text);
            stmt.setInt(2, level);
            stmt.executeUpdate();
            try (ResultSet rs = stmt.getGeneratedKeys()) {
                if (rs.next()) {
                    return rs.getInt(1);
                }
            }
        } catch (SQLException e) {
            logger.error("❌ 插入运势失败：{}", e.getMessage(), e);
        }
        return -1;
    }

    public boolean delete(int id) {
        String sql = "DELETE FROM fortunes WHERE id = ?";
        try (Connection conn = getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setInt(1, id);
            return stmt.executeUpdate() > 0;
        } catch (SQLException e) {
            logger.error("❌ 删除运势失败：{}", e.getMessage(), e);
        }
        return false;
    }

    public void deleteAll() {
        try (Connection conn = getConnection();
             Statement stmt = conn.createStatement()) {
            stmt.execute("DELETE FROM fortunes");
            stmt.execute("ALTER TABLE fortunes ALTER COLUMN id RESTART WITH 1");
        } catch (SQLException e) {
            logger.error("❌ 清空表失败：{}", e.getMessage(), e);
        }
    }

    public boolean isEmpty() {
        return count() == 0;
    }

    public void seed(List<Fortune> fortunes) {
        for (Fortune f : fortunes) {
            insert(f.getText(), f.getLevel());
        }
        logger.info("🌱 从文件导入 {} 条种子数据", fortunes.size());
    }
}

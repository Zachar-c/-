package com.example.service;

import com.example.config.AppConfig;
import com.example.model.Fortune;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;

class FortuneServiceTest {

    private FortuneService service;

    @BeforeEach
    void setUp() {
        String dbUrl = "jdbc:h2:mem:testdb-" + UUID.randomUUID() + ";DB_CLOSE_DELAY=-1";
        AppConfig config = new AppConfig(8080, "data/fortunes.txt", dbUrl, "sa", "");
        service = new FortuneService(config);
        clearAndSeedTestData();
    }

    private void clearAndSeedTestData() {
        service.clearAll();
        service.addFortune("大吉：测试1", 5);
        service.addFortune("中吉：测试2", 4);
        service.addFortune("凶：测试3", 1);
    }

    @Test
    void shouldReturnFortuneInList() {
        Fortune fortune = service.getRandomFortune();
        assertNotNull(fortune);
        String text = fortune.getText();
        assertTrue(text.startsWith("大吉")
                || text.startsWith("中吉")
                || text.startsWith("凶"));
    }

    @Test
    void shouldReturnAllFortunes() {
        List<Fortune> all = service.getAllFortunes();
        assertEquals(3, all.size());
    }

    @Test
    void shouldReturnCorrectCount() {
        assertEquals(3, service.getFortuneCount());
    }

    @Test
    void shouldFilterByLevel() {
        List<Fortune> level5 = service.getFortunesByLevel(5);
        assertEquals(1, level5.size());
        assertEquals("大吉：测试1", level5.get(0).getText());
    }

    @Test
    void shouldFindById() {
        Fortune fortune = service.getFortuneById(0);
        assertEquals("大吉：测试1", fortune.getText());
    }

    @Test
    void shouldReturnNullForInvalidId() {
        assertNull(service.getFortuneById(-1));
        assertNull(service.getFortuneById(100));
    }

    @Test
    void shouldAddFortune() {
        boolean success = service.addFortune("小吉：新增", 3);
        assertTrue(success);
        assertEquals(4, service.getFortuneCount());
    }

    @Test
    void shouldRejectInvalidFortune() {
        assertFalse(service.addFortune("", 3));
        assertFalse(service.addFortune("test", 0));
        assertFalse(service.addFortune("test", 7));
        assertFalse(service.addFortune(null, 3));
    }

    @Test
    void shouldDeleteFortune() {
        assertTrue(service.deleteFortune(0));
        assertEquals(2, service.getFortuneCount());
    }

    @Test
    void shouldRejectInvalidDelete() {
        assertFalse(service.deleteFortune(-1));
        assertFalse(service.deleteFortune(100));
    }
}

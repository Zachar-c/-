package com.example.model;

public class Fortune {
    private String text;
    private int level; // 1-5星，加点趣味

    public Fortune(String text, int level) {
        this.text = text;
        this.level = level;
    }

    public String getText() { return text; }
    public int getLevel() { return level; }

    @Override
    public String toString() {
        return "🌟 ".repeat(level) + text; // 好玩，Java 11+支持
    }
}
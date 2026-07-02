package com.example.model;

public class Fortune {
    private String text;
    private int level; // 1-6星，加点趣味
    private String display;

    public Fortune(String text, int level) {
        this.text = text;
        this.level = level;
        this.display = "🌟 ".repeat(level) + text;
    }

    public String getText() { return text; }
    public int getLevel() { return level; }
    public String getDisplay() { return display; }

    @Override
    public String toString() {
        return display;
    }
}
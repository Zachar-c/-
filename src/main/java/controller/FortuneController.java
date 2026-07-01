package com.example.controller;

import com.sun.net.httpserver.HttpExchange;
import com.example.model.Fortune;
import com.example.service.FortuneService;

import java.io.IOException;
import java.io.OutputStream;
import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.stream.Collectors;

public class FortuneController {
    private final FortuneService service = new FortuneService();

    public void handle(HttpExchange exchange) throws IOException {
        if (!"GET".equals(exchange.getRequestMethod())) {
            exchange.sendResponseHeaders(405, -1);
            return;
        }

        String path = exchange.getRequestURI().getPath();
        String response;
        int statusCode = 200;

        if ("/fortune/list".equals(path)) {
            response = formatFortunes(service.getAllFortunes());
        } else if ("/fortune/count".equals(path)) {
            response = String.valueOf(service.getFortuneCount());
        } else if (path.startsWith("/fortune/level/")) {
            String levelPart = path.substring("/fortune/level/".length());
            try {
                int level = Integer.parseInt(levelPart);
                List<Fortune> matched = service.getFortunesByLevel(level);
                if (matched.isEmpty()) {
                    statusCode = 404;
                    response = "没有找到 " + level + " 星运势";
                } else {
                    response = formatFortunes(matched);
                }
            } catch (NumberFormatException e) {
                statusCode = 400;
                response = "星级必须是数字：" + levelPart;
            }
        } else if (path.startsWith("/fortune/")) {
            String idPart = path.substring("/fortune/".length());
            try {
                int id = Integer.parseInt(idPart);
                Fortune fortune = service.getFortuneById(id);
                if (fortune == null) {
                    statusCode = 404;
                    response = "id 超出范围：" + id;
                } else {
                    response = fortune.toString();
                }
            } catch (NumberFormatException e) {
                statusCode = 400;
                response = "id 必须是数字：" + idPart;
            }
        } else {
            response = service.getRandomFortune().toString();
        }

        sendResponse(exchange, response, statusCode);
    }

    private String formatFortunes(List<Fortune> fortunes) {
        return fortunes.stream()
                .map(Fortune::toString)
                .collect(Collectors.joining("\n"));
    }

    private void sendResponse(HttpExchange exchange, String response, int statusCode) throws IOException {
        byte[] bytes = response.getBytes(StandardCharsets.UTF_8);
        exchange.getResponseHeaders().set("Content-Type", "text/plain; charset=UTF-8");
        exchange.sendResponseHeaders(statusCode, bytes.length);
        try (OutputStream os = exchange.getResponseBody()) {
            os.write(bytes);
        }
    }
}

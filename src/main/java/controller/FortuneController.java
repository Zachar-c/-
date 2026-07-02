package com.example.controller;

import com.google.gson.Gson;
import com.sun.net.httpserver.HttpExchange;
import com.example.model.Fortune;
import com.example.service.FortuneService;

import java.io.IOException;
import java.io.OutputStream;
import java.nio.charset.StandardCharsets;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

public class FortuneController {
    private final FortuneService service = new FortuneService();
    private final Gson gson = new Gson();

    public void handle(HttpExchange exchange) throws IOException {
        if (!"GET".equals(exchange.getRequestMethod())) {
            sendJson(exchange, errorResponse("仅支持 GET 请求"), 405);
            return;
        }

        String path = exchange.getRequestURI().getPath();
        String response;
        int statusCode = 200;

        if ("/fortune/list".equals(path)) {
            response = listResponse(service.getAllFortunes());
        } else if ("/fortune/count".equals(path)) {
            response = countResponse(service.getFortuneCount());
        } else if (path.startsWith("/fortune/level/")) {
            String levelPart = path.substring("/fortune/level/".length());
            try {
                int level = Integer.parseInt(levelPart);
                List<Fortune> matched = service.getFortunesByLevel(level);
                if (matched.isEmpty()) {
                    statusCode = 404;
                    response = errorResponse("没有找到 " + level + " 星运势");
                } else {
                    response = listResponse(matched);
                }
            } catch (NumberFormatException e) {
                statusCode = 400;
                response = errorResponse("星级必须是数字：" + levelPart);
            }
        } else if (path.startsWith("/fortune/")) {
            String idPart = path.substring("/fortune/".length());
            try {
                int id = Integer.parseInt(idPart);
                Fortune fortune = service.getFortuneById(id);
                if (fortune == null) {
                    statusCode = 404;
                    response = errorResponse("id 超出范围：" + id);
                } else {
                    response = gson.toJson(fortune);
                }
            } catch (NumberFormatException e) {
                statusCode = 400;
                response = errorResponse("id 必须是数字：" + idPart);
            }
        } else {
            response = gson.toJson(service.getRandomFortune());
        }

        sendJson(exchange, response, statusCode);
    }

    private String listResponse(List<Fortune> fortunes) {
        Map<String, Object> map = new LinkedHashMap<>();
        map.put("count", fortunes.size());
        map.put("data", fortunes);
        return gson.toJson(map);
    }

    private String countResponse(int count) {
        Map<String, Object> map = new LinkedHashMap<>();
        map.put("count", count);
        return gson.toJson(map);
    }

    private String errorResponse(String message) {
        Map<String, Object> map = new LinkedHashMap<>();
        map.put("error", message);
        return gson.toJson(map);
    }

    private void sendJson(HttpExchange exchange, String response, int statusCode) throws IOException {
        byte[] bytes = response.getBytes(StandardCharsets.UTF_8);
        exchange.getResponseHeaders().set("Content-Type", "application/json; charset=UTF-8");
        exchange.sendResponseHeaders(statusCode, bytes.length);
        try (OutputStream os = exchange.getResponseBody()) {
            os.write(bytes);
        }
    }
}

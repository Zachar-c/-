package com.example.controller;

import com.google.gson.Gson;
import com.sun.net.httpserver.HttpExchange;
import com.example.model.Fortune;
import com.example.service.FortuneService;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.nio.charset.StandardCharsets;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

public class FortuneController {
    private final FortuneService service = new FortuneService();
    private final Gson gson = new Gson();

    public void handle(HttpExchange exchange) throws IOException {
        String method = exchange.getRequestMethod();
        String path = exchange.getRequestURI().getPath();

        try {
            if ("GET".equals(method)) {
                handleGet(exchange, path);
            } else if ("POST".equals(method)) {
                handlePost(exchange);
            } else if ("DELETE".equals(method)) {
                handleDelete(exchange, path);
            } else {
                sendJson(exchange, errorResponse("仅支持 GET/POST/DELETE 请求"), 405);
            }
        } catch (Exception e) {
            sendJson(exchange, errorResponse("服务器内部错误：" + e.getMessage()), 500);
        }
    }

    private void handleGet(HttpExchange exchange, String path) throws IOException {
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

    private void handlePost(HttpExchange exchange) throws IOException {
        String body = readBody(exchange);
        Map<String, String> params = parseForm(body);

        String text = params.get("text");
        String levelStr = params.get("level");

        if (text == null || text.trim().isEmpty()) {
            sendJson(exchange, errorResponse("text 参数不能为空"), 400);
            return;
        }

        int level;
        try {
            level = Integer.parseInt(levelStr);
        } catch (NumberFormatException e) {
            sendJson(exchange, errorResponse("level 必须是数字：" + levelStr), 400);
            return;
        }

        if (level < 1 || level > 6) {
            sendJson(exchange, errorResponse("level 必须在 1-6 之间：" + level), 400);
            return;
        }

        boolean success = service.addFortune(text, level);
        if (success) {
            sendJson(exchange, countResponse(service.getFortuneCount()), 201);
        } else {
            sendJson(exchange, errorResponse("添加失败"), 500);
        }
    }

    private void handleDelete(HttpExchange exchange, String path) throws IOException {
        if (!path.startsWith("/fortune/")) {
            sendJson(exchange, errorResponse("DELETE 请求格式错误"), 400);
            return;
        }

        String idPart = path.substring("/fortune/".length());
        try {
            int id = Integer.parseInt(idPart);
            boolean success = service.deleteFortune(id);
            if (success) {
                sendJson(exchange, countResponse(service.getFortuneCount()), 200);
            } else {
                sendJson(exchange, errorResponse("id 超出范围：" + id), 404);
            }
        } catch (NumberFormatException e) {
            sendJson(exchange, errorResponse("id 必须是数字：" + idPart), 400);
        }
    }

    private String readBody(HttpExchange exchange) throws IOException {
        try (BufferedReader reader = new BufferedReader(new InputStreamReader(exchange.getRequestBody(), StandardCharsets.UTF_8))) {
            return reader.lines().collect(Collectors.joining("\n"));
        }
    }

    private Map<String, String> parseForm(String body) {
        Map<String, String> map = new LinkedHashMap<>();
        if (body == null || body.isEmpty()) {
            return map;
        }
        for (String pair : body.split("&")) {
            String[] kv = pair.split("=", 2);
            if (kv.length == 2) {
                map.put(kv[0], decode(kv[1]));
            }
        }
        return map;
    }

    private String decode(String value) {
        try {
            return java.net.URLDecoder.decode(value.replace("+", " "), StandardCharsets.UTF_8.name());
        } catch (Exception e) {
            return value;
        }
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

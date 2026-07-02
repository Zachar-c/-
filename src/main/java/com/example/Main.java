package com.example;

import com.sun.net.httpserver.HttpServer;
import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpHandler;
import com.example.controller.FortuneController;

import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.InetSocketAddress;

public class Main {
    public static void main(String[] args) throws Exception {
        HttpServer server = HttpServer.create(new InetSocketAddress(8080), 0);
        FortuneController controller = new FortuneController();

        server.createContext("/fortune", controller::handle);
        server.createContext("/", new StaticPageHandler("/static/index.html"));
        server.setExecutor(null);
        server.start();

        System.out.println("🏠 Maven 项目已启动！访问 http://localhost:8080");
    }

    static class StaticPageHandler implements HttpHandler {
        private final String resourcePath;

        public StaticPageHandler(String resourcePath) {
            this.resourcePath = resourcePath;
        }

        @Override
        public void handle(HttpExchange exchange) throws IOException {
            if (!"GET".equals(exchange.getRequestMethod())) {
                exchange.sendResponseHeaders(405, -1);
                return;
            }

            String path = exchange.getRequestURI().getPath();
            if (path.equals("/")) {
                path = resourcePath;
            } else {
                path = "/static" + path;
            }

            try (InputStream input = getClass().getResourceAsStream(path)) {
                if (input == null) {
                    String response = "404 Not Found";
                    exchange.sendResponseHeaders(404, response.getBytes().length);
                    try (OutputStream os = exchange.getResponseBody()) {
                        os.write(response.getBytes());
                    }
                    return;
                }

                byte[] bytes = input.readAllBytes();
                String contentType = path.endsWith(".html") ? "text/html" : "application/octet-stream";
                exchange.getResponseHeaders().set("Content-Type", contentType + "; charset=UTF-8");
                exchange.sendResponseHeaders(200, bytes.length);
                try (OutputStream os = exchange.getResponseBody()) {
                    os.write(bytes);
                }
            }
        }
    }
}

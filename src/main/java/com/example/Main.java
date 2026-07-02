package com.example;

import com.sun.net.httpserver.HttpServer;
import com.example.controller.FortuneController;
import java.net.InetSocketAddress;

public class Main {
    public static void main(String[] args) throws Exception {
        HttpServer server = HttpServer.create(new InetSocketAddress(8080), 0);
        FortuneController controller = new FortuneController();

        server.createContext("/fortune", controller::handle);
        server.setExecutor(null);
        server.start();

        System.out.println("🏠 Maven 项目已启动！访问 http://localhost:8080/fortune");
    }
}
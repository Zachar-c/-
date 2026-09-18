import com.sun.net.httpserver.HttpServer;
import com.sun.net.httpserver.HttpExchange;
import java.io.IOException;
import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.util.Random;

public class FortuneServer {

    // 运势池（头脑风暴时刻：你可以随意往里加有趣的中文词）
    private static final String[] FORTUNES = {
        "🌟 鸿运当头，今天必有好事发生！",
        "🍀 保持微笑，幸运正在路上。",
        "✨ 适合大胆尝试，别怕犯错。",
        "💪 今天你比代码更强大！",
        "🎉 晚上可能会有意外惊喜。"
    };

    public static void main(String[] args) throws IOException {
        // 1. 创建本地服务器，监听 8080 端口
        HttpServer server = HttpServer.create(new InetSocketAddress(8080), 0);
        
        // 2. 创建路由：当访问 /fortune 时，执行后面的逻辑
        server.createContext("/fortune", (HttpExchange exchange) -> {
            // 3. 头脑风暴小插曲：我们只处理 GET 请求
            if ("GET".equals(exchange.getRequestMethod())) {
                // 随机选一条运势
                String response = FORTUNES[new Random().nextInt(FORTUNES.length)];
                
                // 4. 设置响应头（200表示成功）并返回 UTF-8 内容
                byte[] responseBytes = response.getBytes(StandardCharsets.UTF_8);
                exchange.getResponseHeaders().set("Content-Type", "text/plain; charset=UTF-8");
                exchange.sendResponseHeaders(200, responseBytes.length);
                OutputStream os = exchange.getResponseBody();
                os.write(responseBytes);
                os.close();
            } else {
                // 如果不是GET，返回405方法不允许
                exchange.sendResponseHeaders(405, -1);
            }
        });

        // 5. 启动服务器（设置默认执行器）
        server.setExecutor(null);
        server.start();
        
        // 6. 控制台打印提示信息（这就是你的“快乐反馈”）
        System.out.println("🎯 运势服务器已启动！");
        System.out.println("🌐 请在浏览器访问: http://localhost:8080/fortune");
        System.out.println("🛑 按 Ctrl + C 停止服务。");
    }
}
import com.sun.net.httpserver.HttpServer;
import controller.FortuneController;
import java.net.InetSocketAddress;

public class Main {
    public static void main(String[] args) throws Exception {
        HttpServer server = HttpServer.create(new InetSocketAddress(8080), 0);
        FortuneController controller = new FortuneController(); // 布置客厅

        server.createContext("/fortune", controller::handle); // 挂上招牌
        server.setExecutor(null);
        server.start();
        
        System.out.println("🏠 分层架构项目已启动！访问 http://localhost:8080/fortune");
    }
}
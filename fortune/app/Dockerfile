# 阶段 1：编译并打包 uber-jar
FROM maven:3.9.9-eclipse-temurin-11-alpine AS builder

WORKDIR /build
COPY pom.xml .
COPY src ./src

RUN mvn -B clean package -DskipTests

# 阶段 2：仅保留 JRE 运行
FROM eclipse-temurin:11-jre-alpine

WORKDIR /app

# 创建非 root 用户运行应用
RUN addgroup -S fortune && adduser -S fortune -G fortune

# 拷贝构建产物
COPY --from=builder /build/target/fortune-app-1.8.0.jar app.jar

# 数据目录由 docker-compose 挂载，这里创建并赋权
RUN mkdir -p /app/data /app/logs && chown -R fortune:fortune /app

USER fortune

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "app.jar"]

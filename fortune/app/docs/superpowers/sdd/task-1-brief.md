### Task 1: 添加 `.dockerignore`

**Files:**
- Create: `.dockerignore`

**Interfaces:**
- Consumes: 无
- Produces: `.dockerignore` 被 Docker build context 读取

- [ ] **Step 1: 创建 `.dockerignore` 文件**

```text
# Git
.git
.gitignore

# Maven build output
target/

# IDE
.idea/
*.iml
.vscode/

# Runtime data (persisted via volume, not image)
data/
logs/

# Local env / docs not needed in image
*.md
.github/
docs/
```

- [ ] **Step 2: 验证 build context 大小**

Run:

```bash
docker build -t fortune-app:test-build . --no-cache 2>&1 | tail -n 5
```

Expected: 构建命令能正常开始（不会把 `target/` 或 `.git/` 传入 context）。

- [ ] **Step 3: Commit**

```bash
git add .dockerignore
git commit -m "chore: add .dockerignore to reduce build context"
```

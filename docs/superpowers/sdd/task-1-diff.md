diff --git a/.dockerignore b/.dockerignore
new file mode 100644
index 0000000..958f7fa
--- /dev/null
+++ b/.dockerignore
@@ -0,0 +1,20 @@
+# Git
+.git
+.gitignore
+
+# Maven build output
+target/
+
+# IDE
+.idea/
+*.iml
+.vscode/
+
+# Runtime data (persisted via volume, not image)
+data/
+logs/
+
+# Local env / docs not needed in image
+*.md
+.github/
+docs/

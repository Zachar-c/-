class_name GameVersion
extends RefCounted
## 语义化版本 2.0（https://semver.org/lang/zh-CN/）单源定义。
## 格式：MAJOR.MINOR.PATCH[-预发布][+构建元数据]；构建元数据不影响优先级。
## 改动版本时只改这里，各屏版本号统一引用本类。

const MAJOR := 0
const MINOR := 9
const PATCH := 0
## 预发布标识（如 "alpha.1"），无预发布时留空。
const PRERELEASE := ""
## 构建元数据（如 "local" / "nightly.20260908"），不影响版本优先级。
## 正式发布留空（输出 0.9.0）；本地/调试构建可临时填 "local"。
const BUILD_META := ""


## 完整语义化版本号：0.9.0
static func semver() -> String:
	var v := "%d.%d.%d" % [MAJOR, MINOR, PATCH]
	if not PRERELEASE.is_empty():
		v += "-" + PRERELEASE
	if not BUILD_META.is_empty():
		v += "+" + BUILD_META
	return v


## 展示用标签：BUILD 0.9.0
static func display() -> String:
	return "BUILD " + semver()

# go2shell Makefile
# 使用 Swift Package Manager 构建 macOS 应用

.PHONY: all build clean install uninstall run run-ui run-settings test help icon reset debug

# 变量定义
APP_NAME = go2shell
BUNDLE_ID = com.solarhell.go2shell
BUILD_DIR = .build
RELEASE_DIR = $(BUILD_DIR)/release
APP_BUNDLE = $(BUILD_DIR)/$(APP_NAME).app
INSTALL_PATH = /Applications/$(APP_NAME).app

# FinderSync 扩展
SDK_PATH := $(shell xcrun --show-sdk-path --sdk macosx)
ARCH := $(shell uname -m)
TARGET := $(ARCH)-apple-macosx15.0
EXT_DIR = FinderSyncExtension
TERM_EXT = $(BUILD_DIR)/go2shellTerminal.appex
COPY_EXT = $(BUILD_DIR)/go2shellCopy.appex

# 默认目标
all: build

# 显示帮助信息
help:
	@echo "go2shell 构建系统 (基于 Swift Package Manager)"
	@echo ""
	@echo "可用命令:"
	@echo "  make build      - 构建应用（默认）"
	@echo "  make clean      - 清理构建文件"
	@echo "  make install    - 安装到 /Applications"
	@echo "  make uninstall  - 从 /Applications 卸载"
	@echo "  make run        - 运行应用（显示设置界面）"
	@echo "  make run-settings - 运行应用（高级设置）"
	@echo "  make test       - 运行测试"
	@echo "  make icon       - 生成应用图标"
	@echo "  make reset      - 重置 Finder 和扩展"
	@echo "  make debug      - 显示调试信息"
	@echo ""

# 构建应用
build:
	@echo "🔨 开始构建 go2shell..."
	@echo ""

	# 使用 SPM 构建 Release 版本
	@echo "📦 使用 Swift Package Manager 编译主应用..."
	@swift build -c release
	@echo "✅ 主应用编译完成"
	@echo ""

	# 构建 FinderSync 扩展
	@echo "🔌 构建 FinderSync 扩展..."
	@$(MAKE) --no-print-directory build-extensions
	@echo "✅ 扩展构建完成"
	@echo ""

	# 创建 App Bundle
	@echo "📁 创建 App Bundle 结构..."
	@$(MAKE) --no-print-directory create-bundle
	@echo "✅ App Bundle 创建完成"
	@echo ""

	# 代码签名
	@echo "✍️  代码签名..."
	@$(MAKE) --no-print-directory codesign
	@echo "✅ 代码签名完成"
	@echo ""

	@echo "✅ 构建完成！"
	@echo "📦 应用位置: $(APP_BUNDLE)"
	@echo ""
	@echo "下一步: make install"

# 构建两个 FinderSync .appex
build-extensions: build-terminal-ext build-copy-ext

build-terminal-ext:
	@echo "  → Building TerminalSync extension"
	@rm -rf $(TERM_EXT)
	@mkdir -p $(TERM_EXT)/Contents/MacOS
	@mkdir -p $(TERM_EXT)/Contents/Resources
	@swiftc -target $(TARGET) \
	        -sdk $(SDK_PATH) \
	        -O -parse-as-library \
	        -Xlinker -e -Xlinker _NSExtensionMain \
	        -framework Foundation -framework AppKit -framework FinderSync \
	        -o $(TERM_EXT)/Contents/MacOS/go2shellTerminal \
	        $(EXT_DIR)/TerminalSync/FinderSyncController.swift \
	        $(EXT_DIR)/TerminalSync/TerminalLauncher.swift \
	        $(EXT_DIR)/TerminalSync/main.swift
	@cp $(EXT_DIR)/TerminalSync/Info.plist $(TERM_EXT)/Contents/Info.plist
	@codesign --force --sign - \
	        --entitlements $(EXT_DIR)/TerminalSync/FinderSync.entitlements \
	        $(TERM_EXT)

build-copy-ext:
	@echo "  → Building CopySync extension"
	@rm -rf $(COPY_EXT)
	@mkdir -p $(COPY_EXT)/Contents/MacOS
	@mkdir -p $(COPY_EXT)/Contents/Resources
	@swiftc -target $(TARGET) \
	        -sdk $(SDK_PATH) \
	        -O -parse-as-library \
	        -Xlinker -e -Xlinker _NSExtensionMain \
	        -framework Foundation -framework AppKit -framework FinderSync \
	        -o $(COPY_EXT)/Contents/MacOS/go2shellCopy \
	        $(EXT_DIR)/CopySync/FinderSyncController.swift \
	        $(EXT_DIR)/CopySync/main.swift
	@cp $(EXT_DIR)/CopySync/Info.plist $(COPY_EXT)/Contents/Info.plist
	@codesign --force --sign - \
	        --entitlements $(EXT_DIR)/CopySync/FinderSync.entitlements \
	        $(COPY_EXT)

# 创建 App Bundle 结构
create-bundle:
	@rm -rf $(APP_BUNDLE)
	@mkdir -p $(APP_BUNDLE)/Contents/MacOS
	@mkdir -p $(APP_BUNDLE)/Contents/Resources
	@mkdir -p $(APP_BUNDLE)/Contents/PlugIns

	# 复制主应用可执行文件
	@cp $(RELEASE_DIR)/go2shell $(APP_BUNDLE)/Contents/MacOS/

	# 嵌入 FinderSync 扩展
	@cp -R $(TERM_EXT) $(APP_BUNDLE)/Contents/PlugIns/
	@cp -R $(COPY_EXT) $(APP_BUNDLE)/Contents/PlugIns/

	# 复制 SPM resource bundle（本地化资源等）
	@for bundle in $(BUILD_DIR)/*-apple-macosx/release/*.bundle; do \
		if [ -d "$$bundle" ]; then \
			cp -r "$$bundle" $(APP_BUNDLE)/Contents/Resources/; \
		fi; \
	done

	# 复制主应用配置
	@cp Resources/Info.plist $(APP_BUNDLE)/Contents/

	# 复制图标（如果存在）
	@if [ -f Resources/AppIcon.icns ]; then \
		cp Resources/AppIcon.icns $(APP_BUNDLE)/Contents/Resources/; \
	fi

	# 复制本地化资源
	@for lproj in Resources/*.lproj; do \
		if [ -d "$$lproj" ]; then \
			cp -r "$$lproj" $(APP_BUNDLE)/Contents/Resources/; \
		fi; \
	done

# 代码签名（扩展已在 build 阶段单独签名，此处只签主 app）
codesign:
	# 先确保嵌入的扩展签名完好
	@codesign --force --sign - \
		--entitlements $(EXT_DIR)/TerminalSync/FinderSync.entitlements \
		$(APP_BUNDLE)/Contents/PlugIns/go2shellTerminal.appex
	@codesign --force --sign - \
		--entitlements $(EXT_DIR)/CopySync/FinderSync.entitlements \
		$(APP_BUNDLE)/Contents/PlugIns/go2shellCopy.appex
	# 签名主应用（不 --deep，避免覆盖扩展 entitlements）
	@codesign --force --sign - \
		--entitlements Resources/go2shell.entitlements \
		$(APP_BUNDLE)

# 清理构建文件
clean:
	@echo "🧹 清理构建文件..."
	@swift package clean
	@rm -rf $(BUILD_DIR)
	@rm -rf .swiftpm
	@echo "✅ 清理完成"

# 安装到 /Applications
install: build
	@echo "📦 安装 go2shell 到 /Applications..."
	@if [ -d "$(INSTALL_PATH)" ]; then \
		echo "⚠️  $(INSTALL_PATH) 已存在，将覆盖"; \
		rm -rf "$(INSTALL_PATH)"; \
	fi
	@cp -r $(APP_BUNDLE) $(INSTALL_PATH)
	@echo "✅ 应用已安装到 $(INSTALL_PATH)"
	@echo ""
	@echo "🔌 重新注册 App 与 FinderSync 扩展..."
	@# lsregister -f 触发 LaunchServices 重新扫描整个 app，pluginkit 也会 re-index
	@/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister -f $(INSTALL_PATH)
	@sleep 1
	@pluginkit -a $(INSTALL_PATH)/Contents/PlugIns/go2shellTerminal.appex
	@pluginkit -a $(INSTALL_PATH)/Contents/PlugIns/go2shellCopy.appex
	@pluginkit -e use -i com.solarhell.go2shell.TerminalSync
	@pluginkit -e use -i com.solarhell.go2shell.CopySync
	@sleep 2
	@if pluginkit -m -v 2>/dev/null | grep -q "com.solarhell.go2shell.TerminalSync"; then \
		echo "  ✓ TerminalSync 已注册"; \
	else \
		echo "  ✗ TerminalSync 未注册"; exit 1; \
	fi
	@if pluginkit -m -v 2>/dev/null | grep -q "com.solarhell.go2shell.CopySync"; then \
		echo "  ✓ CopySync 已注册"; \
	else \
		echo "  ✗ CopySync 未注册"; exit 1; \
	fi
	@killall Finder 2>/dev/null || true
	@echo "✅ Finder 已重启"
	@echo ""

# 卸载
uninstall:
	@echo "🗑️  卸载 go2shell..."
	@if [ -d "$(INSTALL_PATH)" ]; then \
		rm -rf "$(INSTALL_PATH)"; \
		echo "✅ 已卸载 $(INSTALL_PATH)"; \
	else \
		echo "⚠️  $(INSTALL_PATH) 不存在"; \
	fi
	@echo ""
	@echo "💡 如需完全清理，还可以运行:"
	@echo "   defaults delete $(BUNDLE_ID)"

# 运行应用（主界面 - 默认）
run: build
	@echo "🪟 运行 go2shell (主界面)..."
	@$(APP_BUNDLE)/Contents/MacOS/go2shell

# 运行应用（UI 模式 - 别名）
run-ui: run

# 运行应用（设置模式）
run-settings: build
	@echo "⚙️  运行 go2shell (设置模式)..."
	@$(APP_BUNDLE)/Contents/MacOS/go2shell --settings

# 生成图标
icon:
	@if [ ! -f "Resources/icon.png" ]; then \
		echo "❌ 未找到 Resources/icon.png"; \
		echo "请提供一个 1024x1024 的 PNG 图标文件"; \
		exit 1; \
	fi
	@echo "🎨 生成应用图标..."
	@mkdir -p $(BUILD_DIR)/AppIcon.iconset
	@sips -z 16 16     Resources/icon.png --out $(BUILD_DIR)/AppIcon.iconset/icon_16x16.png >/dev/null
	@sips -z 32 32     Resources/icon.png --out $(BUILD_DIR)/AppIcon.iconset/icon_16x16@2x.png >/dev/null
	@sips -z 32 32     Resources/icon.png --out $(BUILD_DIR)/AppIcon.iconset/icon_32x32.png >/dev/null
	@sips -z 64 64     Resources/icon.png --out $(BUILD_DIR)/AppIcon.iconset/icon_32x32@2x.png >/dev/null
	@sips -z 128 128   Resources/icon.png --out $(BUILD_DIR)/AppIcon.iconset/icon_128x128.png >/dev/null
	@sips -z 256 256   Resources/icon.png --out $(BUILD_DIR)/AppIcon.iconset/icon_128x128@2x.png >/dev/null
	@sips -z 256 256   Resources/icon.png --out $(BUILD_DIR)/AppIcon.iconset/icon_256x256.png >/dev/null
	@sips -z 512 512   Resources/icon.png --out $(BUILD_DIR)/AppIcon.iconset/icon_256x256@2x.png >/dev/null
	@sips -z 512 512   Resources/icon.png --out $(BUILD_DIR)/AppIcon.iconset/icon_512x512.png >/dev/null
	@sips -z 1024 1024 Resources/icon.png --out $(BUILD_DIR)/AppIcon.iconset/icon_512x512@2x.png >/dev/null
	@iconutil -c icns $(BUILD_DIR)/AppIcon.iconset -o Resources/AppIcon.icns
	@rm -rf $(BUILD_DIR)/AppIcon.iconset
	@echo "✅ 图标生成完成: Resources/AppIcon.icns"

# 打包 Release zip（用于 Homebrew Cask 分发）
release: build
	@echo "📦 打包 Release..."
	@mkdir -p build
	@cd .build && zip -r ../build/go2shell.zip go2shell.app
	@echo "✅ 打包完成: build/go2shell.zip"
	@shasum -a 256 build/go2shell.zip

# 运行测试
test:
	@echo "🧪 运行测试..."
	@swift test

# 重置 Finder
reset:
	@echo "🔄 重置 Finder..."
	@killall Finder || true
	@echo "✅ 重置完成"

# 调试信息
debug:
	@echo "🔍 调试信息"
	@echo "============"
	@echo "Swift 版本:"
	@swift --version
	@echo ""
	@echo "应用状态:"
	@if [ -d "$(INSTALL_PATH)" ]; then \
		echo "✅ 已安装: $(INSTALL_PATH)"; \
	else \
		echo "❌ 未安装"; \
	fi

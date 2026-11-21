CC = clang
CFLAGS = -O3 -Wall -Wextra -mmacosx-version-min=14.0
FRAMEWORKS = -framework ApplicationServices -framework Carbon
TARGET = autoclicker
GUI_TARGET = AutoClickerGUI
APP_BUNDLE = AutoClicker.app
UNIVERSAL_ARCHS = -arch arm64 -arch x86_64

all: $(TARGET) gui

$(TARGET): autoclicker.c
	$(CC) $(CFLAGS) $(UNIVERSAL_ARCHS) $(FRAMEWORKS) autoclicker.c -o $(TARGET)
	@echo "Build successful: $(TARGET) (Universal arm64 + x86_64, macOS 14.0+)"
	@ls -lh $(TARGET)

gui:
	./build_gui.sh

clean:
	rm -f $(TARGET) $(GUI_TARGET)
	rm -rf $(APP_BUNDLE)

install: $(TARGET)
	mkdir -p $(HOME)/bin
	cp $(TARGET) $(HOME)/bin/$(TARGET)
	@echo "Installed CLI to $(HOME)/bin/$(TARGET)"

install-app: gui
	mkdir -p $(HOME)/Applications
	cp -R $(APP_BUNDLE) $(HOME)/Applications/
	@echo "Installed $(APP_BUNDLE) to $(HOME)/Applications/"

.PHONY: all clean install install-app gui

# asmtone — text as sound (Piano, Chirp, Fast), a Cocoa app in ARM64 assembly, Apple Silicon.
#
#   make           build asmtone.app (signed with your Apple Development identity if found, else ad-hoc)
#   make selftest  build and run the modem self-tests (no window, no sound card)
#   make install   selftest, then install to /Applications, pin to the Dock and launch
#   make icon      redraw the icon (needs Pillow)
#   make clean

CC      := clang
ARCH    := -arch arm64 -mmacosx-version-min=12.0
SRCDIR  := src
SRCS    := $(SRCDIR)/main.s $(SRCDIR)/util.s $(SRCDIR)/audio.s $(SRCDIR)/modem.s \
           $(SRCDIR)/dsp.s $(SRCDIR)/fec.s $(SRCDIR)/selftest.s
OBJS    := $(SRCS:.s=.o)
FRAMEWORKS := -framework Cocoa -framework AudioToolbox -framework CoreAudio -framework AVFoundation
APP     := asmtone.app

SIGN ?= $(shell security find-identity -v -p codesigning 2>/dev/null | awk -F'"' '/Apple Development/ {print $$2; exit}')
ifeq ($(strip $(SIGN)),)
SIGN := -
endif

all: $(APP)

asmtone: $(OBJS)
	$(CC) $(ARCH) -o $@ $(OBJS) $(FRAMEWORKS)

$(SRCDIR)/%.o: $(SRCDIR)/%.s $(SRCDIR)/macros.inc
	$(CC) $(ARCH) -I $(SRCDIR) -c $< -o $@

$(APP): asmtone Info.plist icon/AppIcon.icns
	rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS $(APP)/Contents/Resources
	cp asmtone $(APP)/Contents/MacOS/asmtone
	cp Info.plist $(APP)/Contents/Info.plist
	cp icon/AppIcon.icns $(APP)/Contents/Resources/AppIcon.icns
	printf 'APPL????' > $(APP)/Contents/PkgInfo
	chmod -R u+w $(APP)
	xattr -cr $(APP)
	codesign --force --options runtime --entitlements entitlements.plist --sign "$(SIGN)" $(APP)
	@echo "built $(APP) (signed: $(SIGN))"

selftest: asmtone
	./asmtone --selftest

install: selftest
	sh install.sh

icon:
	python3 icon/make_icon.py

clean:
	rm -rf $(OBJS) asmtone $(APP)

.PHONY: all selftest install icon clean

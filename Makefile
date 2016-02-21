PACKAGE = pam
ORG = amylum

BUILD_DIR = /tmp/$(PACKAGE)-build
RELEASE_DIR = /tmp/$(PACKAGE)-release
RELEASE_FILE = /tmp/$(PACKAGE).tar.gz
PATH_FLAGS = --prefix=/usr --sbindir=/usr/bin --sysconfdir=/etc --libdir=/usr/lib
CONF_FLAGS = --enable-regenerate-docu
CFLAGS =

PACKAGE_VERSION = $$(git --git-dir=upstream/.git describe --tags | cut -d'-' -f3 | sed 's/_/./g')
PATCH_VERSION = $$(cat version)
VERSION = $(PACKAGE_VERSION)-$(PATCH_VERSION)

LIBTIRPC_VERSION = 1.0.1-1
LIBTIRPC_URL = https://github.com/amylum/libtirpc/releases/download/$(LIBTIRPC_VERSION)/libtirpc.tar.gz
LIBTIRPC_TAR = /tmp/libtirpc.tar.gz
LIBTIRPC_DIR = /tmp/libtirpc
LIBTIRPC_PATH = -I$(LIBTIRPC_DIR)/usr/include -L$(LIBTIRPC_DIR)/usr/lib

.PHONY : default submodule manual build_container container deps build version push local

default: submodule container

submodule:
	git submodule update --init

build_container:
	docker build -t pam-pkg meta

manual: submodule build_container
	./meta/launch /bin/bash || true

container: build_container
	./meta/launch

deps:
	rm -rf $(LIBTIRPC_DIR) $(LIBTIRPC_TAR)
	mkdir $(LIBTIRPC_DIR)
	curl -sLo $(LIBTIRPC_TAR) $(LIBTIRPC_URL)
	tar -x -C $(LIBTIRPC_DIR) -f $(LIBTIRPC_TAR)

build: submodule deps
	rm -rf $(BUILD_DIR)
	cp -R upstream $(BUILD_DIR)
	patch -d $(BUILD_DIR) -p1 < patches/fix-libcrypt.patch
	patch -d $(BUILD_DIR) -p1 < patches/fix-compat.patch
	patch -d $(BUILD_DIR) -p1 < patches/libpam-fix-build-with-eglibc-2.16.patch
	patch -d $(BUILD_DIR) -p1 < patches/linux-pam-innetgr.patch
	patch -d $(BUILD_DIR) -p1 < patches/musl-fix-pam_exec.patch
	cd $(BUILD_DIR) && ./autogen.sh
	cd $(BUILD_DIR) && CC=musl-gcc CFLAGS='$(CFLAGS) $(LIBTIRPC_PATH)' ./configure $(PATH_FLAGS) $(CONF_FLAGS)
	cd $(BUILD_DIR) && make && make DESTDIR=$(RELEASE_DIR) install
	mkdir -p $(RELEASE_DIR)/usr/share/licenses/$(PACKAGE)
	cp $(BUILD_DIR)/COPYING $(RELEASE_DIR)/usr/share/licenses/$(PACKAGE)/LICENSE
	cd $(RELEASE_DIR) && tar -czvf $(RELEASE_FILE) *

version:
	@echo $$(($(PATCH_VERSION) + 1)) > version

push: version
	git commit -am "$(VERSION)"
	ssh -oStrictHostKeyChecking=no git@github.com &>/dev/null || true
	git tag -f "$(VERSION)"
	git push --tags origin master
	@sleep 3
	targit -a .github -c -f $(ORG)/$(PACKAGE) $(VERSION) $(RELEASE_FILE)
	@sha512sum $(RELEASE_FILE) | cut -d' ' -f1

local: build push


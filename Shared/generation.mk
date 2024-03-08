GEN_M_FILES = $(wildcard ../Shared/*.m) ../Shared/dylibify/obj-c/dylibify.m ../Shared/TrollStore/Shared/TSUtil.m ../Shared/TrollStore/Exploits/fastPathSign/src/coretrust_bug.c $(wildcard ../Shared/Trollstore/ChOma/src/*.c)
GEN_CFLAGS = -I../Shared/TrollStore/ChOma/src $(shell pkg-config --cflags libcrypto) -Wno-missing-braces
GEN_LDFLAGS = $(shell pkg-config --libs libcrypto)
GEN_FRAMEWORKS = Security
GEN_PRIVATE_FRAMEWORKS = MobileContainerManager

###########################################################################
#
#   makefile
#
#   Core makefile for building MAME and derivatives
#
#   Copyright (c) Nicola Salmoria and the MAME Team.
#   Visit http://mamedev.org for licensing and usage restrictions.
#
###########################################################################

DEBUG=0

UNAME=$(shell uname -a)

ifeq ($(platform),)
   platform = unix
   ifeq ($(UNAME),)
      platform = win
   else ifneq ($(findstring MINGW,$(UNAME)),)
      platform = win
   else ifneq ($(findstring Darwin,$(UNAME)),)
      platform = osx
   else ifneq ($(findstring win,$(UNAME)),)
      platform = win
   endif
else ifneq (,$(findstring armv,$(platform)))
   override platform += unix
endif

# system platform
system_platform = unix
ifeq ($(UNAME),)
   EXE_EXT = .exe
   system_platform = win
else ifneq ($(findstring Darwin,$(UNAME)),)
   system_platform = osx
else ifneq ($(findstring MINGW,$(UNAME)),)
   system_platform = win
endif

# CR/LF setup: use both on win32/os2, CR only on everything else
DEFS = -DCRLF=2 -DDISABLE_MIDI=1
# Default to something reasonable for all platforms
ARFLAGS = -cr

ifeq ($(TARGET),)
   TARGET = mame
   TARGET_NAME = mame2015
endif

EXE =
LIBS =

CORE_DIR := .

ifeq ($(TARGET), mess)
   CORE_DEFINE := -DWANT_MESS
   TARGET_NAME = mess2015
else ifeq ($(TARGET), mame)
   CORE_DEFINE := -DWANT_MAME
   TARGET_NAME = mame2015
else
   CORE_DEFINE := -DWANT_UME
   TARGET_NAME = ume2015
endif
$(info COREDEF = $(CORE_DEFINE))

ifndef SUBTARGET
   SUBTARGET = $(TARGET)
endif

#-------------------------------------------------
# compile flags
# CCOMFLAGS are common flags
# CONLYFLAGS are flags only used when compiling for C
# CPPONLYFLAGS are flags only used when compiling for C++
# COBJFLAGS are flags only used when compiling for Objective-C(++)
#-------------------------------------------------

# start with empties for everything
CCOMFLAGS = -DDISABLE_MIDI -fno-delete-null-pointer-checks
CONLYFLAGS = -fpermissive
CONLYFLAGS += $(CORE_DEFINE)
COBJFLAGS =
CPPONLYFLAGS = -fpermissive
CPPONLYFLAGS += $(CORE_DEFINE)
# LDFLAGS are used generally; LDFLAGSEMULATOR are additional
# flags only used when linking the core emulator
LDFLAGS =
LDFLAGSEMULATOR =

CCOMFLAGS  += -D__LIBRETRO__

$(info UNAME=$(UNAME))

GIT_VERSION ?= " $(shell git rev-parse --short HEAD || echo unknown)"
ifneq ($(GIT_VERSION)," unknown")
	CCOMFLAGS += -DGIT_VERSION=\"$(GIT_VERSION)\"
endif

$(info CFLAGS = $(CONLYFLAGS))
$(info CPPFLAGS = $(CPPONLYFLAGS))

# uncomment next line to build expat as part of MAME build
BUILD_EXPAT = 1

# uncomment next line to build zlib as part of MAME build
ifneq ($(platform), android)
   ifneq ($(platform), emscripten)
      BUILD_ZLIB = 1
   endif
endif
# uncomment next line to build libflac as part of MAME build
BUILD_FLAC = 1

# uncomment next line to build jpeglib as part of MAME build
BUILD_JPEGLIB = 1

# uncomment next line to build PortMidi as part of MAME/MESS build
#BUILD_MIDILIB = 1
VRENDER ?= soft

# Unix
ifneq (,$(findstring unix,$(platform)))
   TARGETLIB := $(TARGET_NAME)_libretro.so
   TARGETOS=linux
   fpic := -fPIC
   SHARED := -shared -Wl,--version-script=src/osd/retro/link.T -Wl,--no-undefined
   CCOMFLAGS += $(fpic) -fsigned-char -finline  -fno-common -fno-builtin -falign-functions=16
   PLATCFLAGS +=  -DALIGN_INTS -DALIGN_SHORTS -fstrict-aliasing
   ifeq ($(VRENDER),opengl)
      PLATCFLAGS += -DHAVE_OPENGL
      LIBS += -lGL
   endif
   LDFLAGS +=  $(fpic) $(SHARED)
   REALCC ?= gcc
   NATIVECC ?= g++
   NATIVECFLAGS ?= -std=gnu99
   BASELIBS += -lpthread
   CXX ?= g++
   #workaround for mame bug (c++ in .c files)
   CC := $(CXX)
   AR ?= @ar
   LD := $(CXX)
   LIBS += -lstdc++ -lpthread -ldl
   ifeq ($(firstword $(filter x86_64,$(UNAME))),x86_64)
      PTR64 = 1
   endif
   ifeq ($(firstword $(filter amd64,$(UNAME))),amd64)
      PTR64 = 1
   endif
   ifeq ($(firstword $(filter ppc64,$(UNAME))),ppc64)
      PTR64 = 1
   endif
   ifeq ($(firstword $(filter aarch64,$(UNAME))),aarch64)
      PTR64 = 1
   endif
   ifeq ($(firstword $(filter arm64,$(UNAME))),arm64)
      PTR64 = 1
   endif
   ifneq (,$(findstring ppc,$(UNAME)))
      BIGENDIAN=1
   endif
   ifneq (,$(findstring armv7,$(UNAME) $(platform)))
      CCOMFLAGS += -mstructure-size-boundary=32
      PLATCFLAGS += -DSDLMAME_NO64BITIO -DSDLMAME_ARM -DRETRO_SETJMP_HACK -DARM
      LDFLAGS += -Wl,--fix-cortex-a8 -Wl,--no-as-needed
      NOASM = 1
      FORCE_DRC_C_BACKEND = 1
   endif
   ifneq (,$(findstring armv8,$(UNAME) $(platform)))
      NOASM = 1
      FORCE_DRC_C_BACKEND = 1
   endif
   CCOMFLAGS += $(PLATCFLAGS)

# OS X
else ifeq ($(platform), osx)
   TARGETLIB := $(TARGET_NAME)_libretro.dylib
   TARGETOS = macosx
   fpic := -fPIC -mmacosx-version-min=10.7
   LIBCXX := libstdc++
   LDFLAGSEMULATOR +=  -stdlib=$(LIBCXX)
   PLATCFLAGS += $(fpic)
   SHARED := -dynamiclib
   CXX_AS = c++
        CC = cc
   LD = $(CXX_AS) -stdlib=$(LIBCXX)
   REALCC   = $(CC)
   NATIVECC = $(CXX_AS)
   NATIVECFLAGS = -std=gnu99
   LDFLAGS +=  $(fpic) $(SHARED)
   AR = @ar
   PYTHON ?= @python
   ifeq ($(COMMAND_MODE),"legacy")
      ARFLAGS = -crs
   endif
   ifeq ($(firstword $(filter x86_64,$(UNAME))),x86_64)
      PTR64 = 1
   endif
   ifeq ($(firstword $(filter amd64,$(UNAME))),amd64)
      PTR64 = 1
   endif
   ifeq ($(firstword $(filter ppc64,$(UNAME))),ppc64)
      PTR64 = 1
   endif
   ifneq (,$(findstring Power,$(UNAME)))
      BIGENDIAN=1
   endif
   PLATCFLAGS += -DSDLMAME_NO64BITIO -DOSX
   CCOMFLAGS += $(PLATCFLAGS)

# iOS
else ifneq (,$(findstring ios,$(platform)))
   FORCE_DRC_C_BACKEND = 1
   TARGETLIB := $(TARGET_NAME)_libretro_ios.dylib
   fpic := -fPIC
   SHARED := -dynamiclib
   TARGETOS = macosx
   LIBCXX := libc++

   IOSSDK := $(shell xcodebuild -version -sdk iphoneos Path)
   CXX_AS := c++
   ifeq ($(platform),ios-arm64)
     CC = $(CXX_AS) -arch arm64 -isysroot $(IOSSDK)
     PTR64 = 1
   else
     CC = $(CXX_AS) -arch armv7 -isysroot $(IOSSDK)
   endif
   LD = $(CXX) -stdlib=$(LIBCXX)
   LDFLAGS +=  $(fpic) $(SHARED)
   REALCC   = $(CC)
   NATIVECC = $(CXX_AS)
   PYTHON ?= @python
   CFLAGS += -DIOS
   LDFLAGSEMULATOR += -stdlib=$(LIBCXX)
   PLATCFLAGS += -DSDLMAME_NO64BITIO -DIOS -DSDLMAME_ARM -DHAVE_POSIX_MEMALIGN
   CCOMFLAGS += $(PLATCFLAGS)

# tvOS
else ifeq ($(platform), tvos-arm64)
   FORCE_DRC_C_BACKEND = 1
   TARGETLIB := $(TARGET_NAME)_libretro_tvos.dylib
   fpic := -fPIC
   SHARED := -dynamiclib
   TARGETOS = macosx
   LIBCXX := libc++
   IOSSDK := $(shell xcodebuild -version -sdk appletvos Path)
   CXX_AS := c++
   CC = $(CXX_AS) -arch arm64 -isysroot $(IOSSDK)
   PTR64 = 1
   LD = $(CXX) -stdlib=$(LIBCXX)
   LDFLAGS +=  $(fpic) $(SHARED)
   REALCC   = $(CC)
   NATIVECC = $(CXX_AS)
   PYTHON ?= @python
   CFLAGS += -DIOS
   LDFLAGSEMULATOR += -stdlib=$(LIBCXX)
   PLATCFLAGS += -DSDLMAME_NO64BITIO -DIOS -DSDLMAME_ARM -DHAVE_POSIX_MEMALIGN
   CCOMFLAGS += $(PLATCFLAGS)

# Android
else ifeq ($(platform), android)
   TARGETLIB := $(TARGET_NAME)_libretro_android.so
   TARGETOS=linux
   fpic := -fPIC
   SHARED := -shared -Wl,--version-script=src/osd/retro/link.T
   CC = @$(ANDROID_NDK_ARM)/bin/arm-linux-androideabi-g++
   AR = @$(ANDROID_NDK_ARM)/bin/arm-linux-androideabi-ar
   LD = @$(ANDROID_NDK_ARM)/bin/arm-linux-androideabi-g++

   FORCE_DRC_C_BACKEND = 1

   CCOMFLAGS += -fPIC -fpic -ffunction-sections -funwind-tables

   PLATCFLAGS += -march=armv7-a -mfloat-abi=softfp -mfpu=vfpv3-d16 -mthumb -DANDROID -DALIGN_INTS -DALIGN_SHORTS -DSDLMAME_NO64BITIO -DSDLMAME_ARM -DRETRO_SETJMP_HACK 

   PLATCFLAGS += -I$(ANDROID_NDK_ROOT)/platforms/android-19/arch-arm/usr/include -I$(ANDROID_NDK_ROOT)/sources/cxx-stl/gnu-libstdc++/4.9/include

   PLATCFLAGS += -I$(ANDROID_NDK_ROOT)/sources/cxx-stl/gnu-libstdc++/4.9/libs/armeabi-v7a/include

   ifeq ($(VRENDER),opengl)
      PLATCFLAGS += -DHAVE_OPENGL
      LIBS += -lGLESv2
      GLES = 1
   endif

   LDFLAGS += $(fpic) $(SHARED) -L$(ANDROID_NDK_ROOT)/sources/cxx-stl/gnu-libstdc++/4.9/libs/armeabi-v7a/thumb

   LDFLAGS += -L$(ANDROID_NDK_ROOT)/platforms/android-19/arch-arm/usr/lib  --sysroot=$(ANDROID_NDK_ROOT)/platforms/android-19/arch-arm -march=armv7-a -mthumb -shared


   REALCC   = $(ANDROID_NDK_ARM)/bin/arm-linux-androideabi-gcc
   NATIVECC = g++
   NATIVECFLAGS = -std=gnu99
   CCOMFLAGS += $(PLATCFLAGS)

   LIBS += -lc -ldl -lm -landroid -llog -lsupc++ $(ANDROID_NDK_ROOT)/sources/cxx-stl/gnu-libstdc++/4.9/libs/armeabi-v7a/thumb/libgnustl_static.a -lgcc

# QNX
else ifeq ($(platform), qnx)
   TARGETLIB := $(TARGET_NAME)_libretro_qnx.so
   TARGETOS=linux
   fpic := -fPIC
   SHARED := -shared -Wl,--version-script=src/osd/retro/link.T

   CC = qcc -Vgcc_ntoarmv7le
   AR = qcc -Vgcc_ntoarmv7le
   CFLAGS += -D__BLACKBERRY_QNX__
   LIBS += -lstdc++ -lpthread

# PS3
else ifeq ($(platform), ps3)
   TARGETLIB := $(TARGET_NAME)_libretro_ps3.a
   CC = $(CELL_SDK)/host-win32/ppu/bin/ppu-lv2-gcc.exe
   AR = $(CELL_SDK)/host-win32/ppu/bin/ppu-lv2-ar.exe
   CFLAGS += -DBLARGG_BIG_ENDIAN=1 -D__ppc__
   STATIC_LINKING = 1
   BIGENDIAN=1
   LIBS += -lstdc++ -lpthread

# sncps3
else ifeq ($(platform), sncps3)
   TARGETLIB := $(TARGET_NAME)_libretro_ps3.a
   CC = $(CELL_SDK)/host-win32/sn/bin/ps3ppusnc.exe
   AR = $(CELL_SDK)/host-win32/sn/bin/ps3snarl.exe
   CFLAGS += -DBLARGG_BIG_ENDIAN=1 -D__ppc__
   STATIC_LINKING = 1
   BIGENDIAN=1
   LIBS += -lstdc++ -lpthread

# Lightweight PS3 Homebrew SDK
else ifeq ($(platform), psl1ght)
   TARGETLIB := $(TARGET_NAME)_libretro_psl1ght.a
   CC = $(PS3DEV)/ppu/bin/ppu-gcc$(EXE_EXT)
   AR = $(PS3DEV)/ppu/bin/ppu-ar$(EXE_EXT)
   CFLAGS += -DBLARGG_BIG_ENDIAN=1 -D__ppc__
   STATIC_LINKING = 1
   BIGENDIAN=1
   LIBS += -lstdc++ -lpthread

# PSP
else ifeq ($(platform), psp1)
   TARGETLIB := $(TARGET_NAME)_libretro_psp1.a
   CC = psp-g++$(EXE_EXT)
   AR = psp-ar$(EXE_EXT)
   CFLAGS += -DPSP -G0
   STATIC_LINKING = 1
   LIBS += -lstdc++ -lpthread

# Xbox 360
else ifeq ($(platform), xenon)
   TARGETLIB := $(TARGET_NAME)_libretro_xenon360.a
   CC = xenon-g++$(EXE_EXT)
   AR = xenon-ar$(EXE_EXT)
   CFLAGS += -D__LIBXENON__ -m32 -D__ppc__
   STATIC_LINKING = 1
   BIGENDIAN=1
   LIBS += -lstdc++ -lpthread

# Nintendo Game Cube
else ifeq ($(platform), ngc)
   TARGETLIB := $(TARGET_NAME)_libretro_ngc.a
   CC = $(DEVKITPPC)/bin/powerpc-eabi-g++$(EXE_EXT)
   AR = $(DEVKITPPC)/bin/powerpc-eabi-ar$(EXE_EXT)
   CFLAGS += -DGEKKO -DHW_DOL -mrvl -mcpu=750 -meabi -mhard-float -DBLARGG_BIG_ENDIAN=1 -D__ppc__
   STATIC_LINKING = 1
   BIGENDIAN=1
   LIBS += -lstdc++ -lpthread

# Nintendo Wii
else ifeq ($(platform), wii)
   TARGETLIB := $(TARGET_NAME)_libretro_wii.a
   CC = $(DEVKITPPC)/bin/powerpc-eabi-g++$(EXE_EXT)
   AR = $(DEVKITPPC)/bin/powerpc-eabi-ar$(EXE_EXT)
   CFLAGS += -DGEKKO -DHW_RVL -mrvl -mcpu=750 -meabi -mhard-float -DBLARGG_BIG_ENDIAN=1 -D__ppc__
   STATIC_LINKING = 1
   BIGENDIAN=1
   LIBS += -lstdc++ -lpthread

# Windows cross compiler
else ifeq ($(platform), wincross)
   TARGETLIB := $(TARGET_NAME)_libretro.dll
   TARGETOS = win32
   CC ?= g++
   LD ?= g++
   SHARED := -shared -static-libgcc -static-libstdc++ -s -Wl,--version-script=src/osd/retro/link.T
   CCOMFLAGS += -D__WIN32__
   LDFLAGS += $(SHARED)
   ifeq ($(VRENDER),opengl)
      CCOMFLAGS += -DHAVE_OPENGL
      LIBS += -lopengl32
   endif
   EXE = .exe
   #LIBS += -lpthread
   DEFS = -DCRLF=3
   ifneq (,$(findstring mingw64-w64,$(PATH)))
      PTR64=1
   endif

# emscripten
else ifeq ($(platform), emscripten)
   TARGETLIB := $(TARGET_NAME)_libretro_emscripten.bc

   NATIVELD = em++
   NATIVELDFLAGS = -Wl,--warn-common -lstdc++
   NATIVECC = em++
   NATIVECFLAGS = -std=gnu99
   REALCC = emcc
   CC_AS = emcc 
   CC = em++ 
   AR = emar
   LD = em++
   FORCE_DRC_C_BACKEND = 1
   CCOMFLAGS += -DLSB_FIRST -fsigned-char -finline  -fno-common -fno-builtin 
   ARFLAGS := rcs
   EXCEPT_FLAGS := -s DISABLE_EXCEPTION_CATCHING=2 \
-s EXCEPTION_CATCHING_WHITELIST='["__ZN15running_machine17start_all_devicesEv",\
"__ZN12cli_frontend7executeEiPPc"]'  -s TOTAL_MEMORY=536870912

   TARGETOS := emscripten
   NOASM := 1
   PLATCFLAGS +=  -s USE_ZLIB=1 -DSDLMAME_NO64BITIO  $(EXCEPT_FLAGS) -DRETRO_EMSCRIPTEN=1 
   PLATCFLAGS += -DALIGN_INTS -DALIGN_SHORTS 
   CCOMFLAGS += $(PLATCFLAGS) #-ffast-math 
   PTR64 = 0
   CFLAGS +=  -s USE_ZLIB=1 
   CXXFLAGS += -s USE_ZLIB=1 
   LDFLAGS += -s USE_ZLIB=1  $(EXCEPT_FLAGS) 
   LDFLAGSEMULATOR +=

# Windows
else
   TARGETLIB := $(TARGET_NAME)_libretro.dll
   TARGETOS = win32
   CC = g++
   LD = g++
   REALCC   = gcc
   NATIVECC = g++
   NATIVECFLAGS = -std=gnu99
   SHARED := -shared -static-libgcc -static-libstdc++ -s -Wl,--version-script=src/osd/retro/link.T
   CCOMFLAGS += -D__WIN32__
   LDFLAGS += $(SHARED)
   ifeq ($(VRENDER),opengl)
      CCOMFLAGS += -DHAVE_OPENGL
      LIBS += -lopengl32
   endif
   EXE = .exe
   LIBS += -lws2_32
   DEFS = -DCRLF=3
   DEFS += -DX64_WINDOWS_ABI
   ifneq ($(findstring MINGW,$(shell uname -a)),)
      PTR64=1
   endif

endif

###########################################################################
#################   BEGIN USER-CONFIGURABLE OPTIONS   #####################
###########################################################################

ifndef TARGET
TARGET = mame
endif

OSD=retro

ifndef PARTIAL
PARTIAL = 0
endif

#-------------------------------------------------
# specify core target: mame, mess, etc.
# specify subtarget: mame, mess, tiny, etc.
# build rules will be included from
# src/$(TARGET)/$(TARGET).mak
#-------------------------------------------------

#-------------------------------------------------
# configure name of final executable
#-------------------------------------------------

# uncomment and specify prefix to be added to the name
# PREFIX =

# uncomment and specify suffix to be added to the name
# SUFFIX =



#-------------------------------------------------
# specify architecture-specific optimizations
#-------------------------------------------------

# uncomment and specify architecture-specific optimizations here
# some examples:
#   ARCHOPTS = -march=pentiumpro  # optimize for I686
#   ARCHOPTS = -march=core2       # optimize for Core 2
#   ARCHOPTS = -march=native      # optimize for local machine (auto detect)
#   ARCHOPTS = -mcpu=G4           # optimize for G4
# note that we leave this commented by default so that you can
# configure this in your environment and never have to think about it
# ARCHOPTS =



#-------------------------------------------------
# specify program options; see each option below
# for details
#-------------------------------------------------

# uncomment the force the universal DRC to always use the C backend
# you may need to do this if your target architecture does not have
# a native backend
# FORCE_DRC_C_BACKEND = 1

###########################################################################
##################   END USER-CONFIGURABLE OPTIONS   ######################
###########################################################################

#-------------------------------------------------
# platform-specific definitions
#-------------------------------------------------

# utilities
MD = -mkdir$(EXE_EXT)
RM = @rm -f
OBJDUMP = @objdump
PYTHON ?= @python2

#-------------------------------------------------
# form the name of the executable
#-------------------------------------------------

# reset all internal prefixes/suffixes
SUFFIX64 =
SUFFIXDEBUG =
SUFFIXPROFILE =

# 64-bit builds get a '64' suffix
ifeq ($(PTR64),1)
SUFFIX64 = 64
endif

# add an EXE suffix to get the final emulator name
EMULATOR = $(TARGET_NAME)

#-------------------------------------------------
# source and object locations
#-------------------------------------------------

# all sources are under the src/ directory
SRC = src

# all 3rd party sources are under the 3rdparty/ directory
3RDPARTY = 3rdparty

# build the targets in different object dirs, so they can co-exist
OBJ = obj
#/$(PREFIX)$(SUFFIXDEBUG)$(SUFFIXPROFILE)

#-------------------------------------------------
# compile-time definitions
#-------------------------------------------------

# define PTR64 if we are a 64-bit target
ifeq ($(PTR64),1)
DEFS += -DPTR64
endif

DEFS += -DNDEBUG

# need to ensure FLAC functions are statically linked
ifeq ($(BUILD_FLAC),1)
DEFS += -DFLAC__NO_DLL
endif

# define USE_SYSTEM_JPEGLIB if library shipped with MAME is not used
ifneq ($(BUILD_JPEGLIB),1)
DEFS += -DUSE_SYSTEM_JPEGLIB
endif

# To support casting in Lua 5.3
DEFS += -DLUA_COMPAT_APIINTCASTS

# CFLAGS is defined based on C or C++ targets
# (remember, expansion only happens when used, so doing it here is ok)
CFLAGS += $(CCOMFLAGS) $(CPPONLYFLAGS)

# we compile C-only to C89 standard with GNU extensions
# we compile C++ code to C++98 standard with GNU extensions
#CONLYFLAGS += -std=gnu89
ifeq ($(platform), osx)
CONLYFLAGS += -ansi
else
CONLYFLAGS += -std=gnu89
endif
CPPONLYFLAGS += -x c++ -std=gnu++98
COBJFLAGS += -x objective-c++

# this speeds it up a bit by piping between the preprocessor/compiler/assembler
CCOMFLAGS += -pipe

# add the optimization flag
ifeq ($(DEBUG), 1)
CCOMFLAGS += -O0 -g
else
CCOMFLAGS += -O3
endif

# if we are optimizing, include optimization options
ifneq ($(DEBUG),1)
CCOMFLAGS += -fno-strict-aliasing $(ARCHOPTS)
endif

# add a basic set of warnings
CCOMFLAGS += \
   -Wall \
   -Wcast-align \
   -Wundef \
   -Wformat-security \
   -Wwrite-strings \
   -Wno-sign-compare \
   -Wno-conversion

# warnings only applicable to C compiles
CONLYFLAGS += \
   -Wpointer-arith \
   -Wbad-function-cast \
   -Wstrict-prototypes

# warnings only applicable to OBJ-C compiles
COBJFLAGS += \
   -Wpointer-arith

# warnings only applicable to C++ compiles
CPPONLYFLAGS += \
   -Woverloaded-virtual

# This should silence some warnings on GCC/Clang
ifneq (,$(findstring clang,$(CC)))
   include $(SRC)/build/flags_clang.mak
else
   ifneq (,$(findstring emcc,$(CC)))
      # Emscripten compiler is based on clang
      include $(SRC)/build/flags_clang.mak
   else
      TEST_GCC = $(shell gcc --version)
      # is it Clang symlinked/renamed to GCC (Xcode 5.0 on OS X)?
      ifeq ($(findstring clang,$(TEST_GCC)),clang)
         include $(SRC)/build/flags_clang.mak
      else
         include $(SRC)/build/flags_gcc.mak
      endif
   endif
endif

#-------------------------------------------------
# include paths
#-------------------------------------------------

# add core include paths
INCPATH += \
	-I$(CORE_DIR)/src/$(TARGET)/layout \
   -I$(SRC)/$(TARGET) \
   -I$(SRC)/$(TARGET)/layout \
   -I$(SRC)/emu \
   -I$(OBJ)/emu \
   -I$(SRC)/emu/layout \
   -I$(SRC)/lib/util \
   -I$(SRC)/lib \
   -I$(3RDPARTY) \
   -I$(SRC)/osd \
   -I$(SRC)/osd/retro \
   -I$(SRC)/osd/retro/libretro-common/include


#-------------------------------------------------
# archiving flags
#-------------------------------------------------


#-------------------------------------------------
# linking flags
#-------------------------------------------------


#-------------------------------------------------
# define the standard object directory; other
# projects can add their object directories to
# this variable
#-------------------------------------------------

OBJDIRS = $(OBJ) $(OBJ)/$(TARGET)/$(SUBTARGET) $(OBJ)/$(TARGET)/$(TARGET)


#-------------------------------------------------
# define standard libarires for CPU and sounds
#-------------------------------------------------

ifneq ($(TARGETOS),emscripten)
LIBEMU = $(OBJ)/libemu.a
LIBOPTIONAL = $(OBJ)/$(TARGET)/$(TARGET)/liboptional.a
LIBDASM = $(OBJ)/$(TARGET)/$(TARGET)/libdasm.a
LIBBUS = $(OBJ)/$(TARGET)/$(TARGET)/libbus.a
LIBUTIL = $(OBJ)/libutil.a
LIBOCORE = $(OBJ)/libocore.a
else
LIBEMU = $(LIBEMUOBJS)
LIBOPTIONAL = $(CPUOBJS) $(SOUNDOBJS) $(VIDEOOBJS) $(MACHINEOBJS) $(NETLISTOBJS)
LIBDASM = $(DASMOBJS) 
LIBBUS = $(BUSOBJS)
LIBUTIL = $(UTILOBJS) 
LIBOCORE = $(OSDCOREOBJS) 
endif

LIBOSD =  $(OBJ)/osd/retro/libretro.o $(OSDOBJS)

VERSIONOBJ = $(OBJ)/version.o
EMUINFOOBJ = $(OBJ)/$(TARGET)/$(TARGET).o
DRIVLISTSRC = $(OBJ)/$(TARGET)/$(SUBTARGET)/drivlist.c
DRIVLISTOBJ = $(OBJ)/$(TARGET)/$(SUBTARGET)/drivlist.o



#-------------------------------------------------
# either build or link against the included
# libraries
#-------------------------------------------------


# add expat XML library
ifeq ($(BUILD_EXPAT),1)
INCPATH += -I$(3RDPARTY)/expat/lib
ifeq ($(TARGETOS),emscripten)
EXPAT =  $(EXPATOBJS) #$(OBJ)/libexpat.a
else
EXPAT =  $(OBJ)/libexpat.a
endif
else
LIBS += -lexpat
EXPAT =
endif

# add ZLIB compression library
ifeq ($(BUILD_ZLIB),1)
INCPATH += -I$(3RDPARTY)/zlib
ZLIB = $(OBJ)/libz.a
else
LIBS += -lz
ZLIB =
endif

# add flac library
ifeq ($(BUILD_FLAC),1)
INCPATH += -I$(SRC)/lib/util -I$(3RDPARTY)/libflac/src/libFLAC/include
ifeq ($(TARGETOS),emscripten)
FLAC_LIB = $(LIBFLACOBJS) #$(OBJ)/libflac.a
else
FLAC_LIB = $(OBJ)/libflac.a
endif
else
LIBS += -lFLAC
FLAC_LIB =
endif

# add jpeglib image library
ifeq ($(BUILD_JPEGLIB),1)
INCPATH += -I$(3RDPARTY)/libjpeg
ifeq ($(TARGETOS),emscripten)
JPEG_LIB = $(LIBJPEGOBJS) #$(OBJ)/libjpeg.a
else
JPEG_LIB = $(OBJ)/libjpeg.a
endif
else
LIBS += -ljpeg
JPEG_LIB =
endif

ifeq ($(TARGETOS),emscripten)
# add SoftFloat floating point emulation library
SOFTFLOAT = $(SOFTFLOATOBJS) #$(OBJ)/libsoftfloat.a

# add formats emulation library
FORMATS_LIB = $(FORMATSOBJS) #$(OBJ)/libformats.a
else
# add SoftFloat floating point emulation library
SOFTFLOAT = $(OBJ)/libsoftfloat.a

# add formats emulation library
FORMATS_LIB = $(OBJ)/libformats.a
endif

# add PortMidi MIDI library
ifeq ($(BUILD_MIDILIB),1)
INCPATH += -I$(SRC)/lib/portmidi
MIDI_LIB = $(OBJ)/libportmidi.a
else
#LIBS += -lportmidi
MIDI_LIB =
endif

ifneq (,$(findstring clang,$(CC)))
ifneq ($(platform), android)
LIBS += -lstdc++ -lpthread
endif
endif
#-------------------------------------------------
# 'default' target needs to go here, before the
# include files which define additional targets
#-------------------------------------------------

default: maketree buildtools emulator

all: default tools

tests: maketree jedutil$(EXE_EXT) chdman$(EXE_EXT)

ifeq ($(TARGETOS),emscripten)
7Z_LIB = $(LIB7ZOBJS) #$(OBJ)/lib7z.a
else
7Z_LIB = $(OBJ)/lib7z.a
endif

#-------------------------------------------------
# defines needed by multiple make files
#-------------------------------------------------

BUILDSRC = $(SRC)/build
BUILDOBJ = $(OBJ)/build
BUILDOUT = $(BUILDOBJ)

include Makefile.common

# combine the various definitions to one
CCOMFLAGS += $(INCPATH)
CDEFS = $(DEFS)

#-------------------------------------------------
# primary targets
#-------------------------------------------------

emulator: maketree $(EMULATOR)

buildtools: maketree

tools: maketree $(TOOLS)

maketree: $(sort $(OBJDIRS))

clean: $(OSDCLEAN)
	@echo Deleting object tree $(OBJ)...
ifeq ($(PARTIAL),1)
	$(RM) -r obj/osd/*
else
	$(RM) -r obj/*
endif
	@echo Deleting $(EMULATOR)...
	$(RM) $(EMULATOR)
	@echo Deleting $(TOOLS)...
	$(RM) $(TOOLS)
	@echo Deleting dependencies...
	$(RM) depend_emu.mak
	$(RM) depend_mame.mak
	$(RM) depend_mess.mak
	$(RM) depend_ume.mak
ifdef MAP
	@echo Deleting $(FULLNAME).map...
	$(RM) $(FULLNAME).map
endif
ifdef SYMBOLS
	@echo Deleting $(FULLNAME).sym...
	$(RM) $(FULLNAME).sym
endif
ifneq ($(PARTIAL),1)
# 	TODO: We should do this smarter at some point
	@echo Deleting build targets...
	$(RM) *_libretro.so *_libretro.dylib *_libretro.dll
endif

checkautodetect:
	@echo TARGETOS=$(TARGETOS)
	@echo PTR64=$(PTR64)
	@echo BIGENDIAN=$(BIGENDIAN)
	@echo UNAME="$(UNAME)"

tests: $(REGTESTS)

mak: maketree $(MAKEMAK_TARGET)
	@echo Rebuilding $(TARGET).mak...
	$(MAKEMAK) $(SRC)/targets/$(TARGET).lst -I. -I$(SRC)/emu -I$(SRC)/$(TARGET) -I$(SRC)/$(TARGET)/layout $(SRC) > $(TARGET).mak
	$(MAKEMAK) $(SRC)/targets/$(TARGET).lst > $(TARGET).lst

#-------------------------------------------------
# directory targets
#-------------------------------------------------

$(sort $(OBJDIRS)):
	$(MD) -p $@

BUILDTOOLS_CUSTOM = 0

ifeq ($(platform), android)
BUILDTOOLS_CUSTOM = 1
else ifeq ($(platform), ios)
BUILDTOOLS_CUSTOM = 1
endif

#-------------------------------------------------
# executable targets and dependencies
#-------------------------------------------------

EXECUTABLE_DEFINED = 1
ifndef EXECUTABLE_DEFINED

ifeq ($(BUSES),)
LIBBUS =
endif

EMULATOROBJLIST = $(EMUINFOOBJ) $(DRIVLISTOBJ) $(DRVLIBS) $(LIBOSD) $(LIBBUS) $(LIBOPTIONAL) $(LIBEMU) $(LIBDASM) $(LIBUTIL) $(EXPAT) $(SOFTFLOAT) $(JPEG_LIB) $(FLAC_LIB) $(7Z_LIB) $(FORMATS_LIB) $(LUA_LIB) $(SQLITE3_LIB) $(WEB_LIB) $(BGFX_LIB) $(ZLIB) $(LIBOCORE) $(MIDI_LIB) $(RESFILE)

ifeq ($(TARGETOS),emscripten)
EMULATOROBJ = $(EMULATOROBJLIST:.a=.bc)
else
EMULATOROBJ = $(EMULATOROBJLIST)
endif

$(EMULATOR): $(VERSIONOBJ) $(EMULATOROBJ)
	@echo Linking $@...
ifeq ($(TARGETOS),emscripten)
# Emscripten's linker seems to be stricter about the ordering of files
	$(LD) $(LDFLAGS) $(LDFLAGSEMULATOR) $(VERSIONOBJ) -Wl,--start-group $(EMULATOROBJ) -Wl,--end-group $(LIBS) -o $@
else
	$(LD) $(LDFLAGS) $(LDFLAGSEMULATOR) $(VERSIONOBJ) $(EMULATOROBJ) $(LIBS) -o $@
endif
ifeq ($(TARGETOS),win32)
ifdef SYMBOLS
ifndef MSVC_BUILD
	$(OBJDUMP) --section=.text --line-numbers --syms --demangle $@ >$(FULLNAME).sym
endif
endif
endif

endif

$(EMULATOR): $(EMUINFOOBJ) $(DRIVLISTOBJ) $(DRVLIBS) $(LIBOSD) $(LIBBUS) $(LIBOPTIONAL) $(LIBEMU) $(LIBDASM) $(LIBUTIL) $(EXPAT) $(SOFTFLOAT) $(JPEG_LIB) $(FLAC_LIB) $(7Z_LIB) $(FORMATS_LIB) $(LUA_LIB) $(SQLITE3_LIB) $(WEB_LIB) $(ZLIB) $(LIBOCORE) $(MIDI_LIB) $(RESFILE)
	$(CC) $(CDEFS) $(CFLAGS) -c $(SRC)/version.c -o $(VERSIONOBJ)
	@echo Linking $(TARGETLIB)
	$(LD) $(LDFLAGS) $(LDFLAGSEMULATOR) $(VERSIONOBJ) $^ $(LIBS) -o $(TARGETLIB)


#-------------------------------------------------
# generic rules
#-------------------------------------------------
ifeq ($(TARGETOS),emscripten)
(EMUOBJ)/memory.o: $(EMUSRC)/memory.c
	$(CC) $(CDEFS) $(CFLAGS) -O1 -c $< -o $@
endif

$(OBJ)/%.o: $(SRC)/%.c | $(OSPREBUILD)
	$(CC) $(CDEFS) $(CFLAGS) -c $< -o $@

$(OBJ)/%.o: $(OBJ)/%.c | $(OSPREBUILD)
	$(CC) $(CDEFS) $(CFLAGS) -c $< -o $@

$(OBJ)/%.pp: $(SRC)/%.c | $(OSPREBUILD)
	$(CC) $(CDEFS) $(CFLAGS) -E $< -o $@

$(OBJ)/%.s: $(SRC)/%.c | $(OSPREBUILD)
	$(CC) $(CDEFS) $(CFLAGS) -S $< -o $@

$(DRIVLISTOBJ): $(DRIVLISTSRC)
	$(CC) $(CDEFS) $(CFLAGS) -c $< -o $@

$(DRIVLISTSRC): $(SRC)/$(TARGET)/$(SUBTARGET).lst $(SRC)/build/makelist.py
	@echo Building driver list $<...
	$(PYTHON) $(SRC)/build/makelist.py $< >$@

ifeq ($(TARGETOS),emscripten)
# Avoid using .a files with Emscripten, link to bitcode instead
$(OBJ)/%.a:
	@echo Linking $@...
	$(RM) $@
	$(LD) $^ -o $@
$(OBJ)/%.bc: $(OBJ)/%.a
	@cp $< $@
else
$(OBJ)/%.a:
	@echo Archiving $@...
	$(RM) $@
	$(AR) $(ARFLAGS) $@ $^
endif

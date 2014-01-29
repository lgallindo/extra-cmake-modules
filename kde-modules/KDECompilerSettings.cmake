# This module sets more useful CMAKE_CXX_FLAGS.
#
# In particular, it enables many more warnings than the default,
# and sets stricter modes for some compiler features.  By default,
# it disables exceptions; kde_target_enable_exceptions() can be used
# to re-enable them for a specific target.
#
#
# This module provides the following functions:
#
#   kde_source_files_enable_exceptions([file1 [file2 [...]]])
#
# Enables exceptions for specific source files.  This should not be
# used on source files in a language other than C++.
#
#   kde_target_enable_exceptions(target <INTERFACE|PUBLIC|PRIVATE>)
#
# Enables exceptions for a specific target.  This should not be used
# on a target that has source files in a language other than C++.
#
#   kde_enable_exceptions()
#
# Enables exceptions for C++ source files compiled for the
# CMakeLists.txt file in the current directory and all subdirectories.
#


############################################################
# Toolchain minimal requirements
#
# Note that only compilers officially supported by Qt are
# supported by this file; workarounds for older compilers
# will generally not be included.  See
# https://qt-project.org/doc/qt-5/supported-platforms.html
# and
# https://community.kde.org/Frameworks/Policies#Frameworks_compiler_requirements_and_C.2B.2B11
# for more details.
############################################################

macro(_kde_compiler_min_version min_version)
    if ("${CMAKE_CXX_COMPILER_VERSION}" VERSION_LESS "${min_version}")
        message(WARNING "Version ${CMAKE_CXX_COMPILER_VERSION} of the ${CMAKE_CXX_COMPILER_ID} C++ compiler is not supported. Please use version ${min_version} or later.")
    endif()
endmacro()

if (MSVC)
    # MSVC_VERSION 1600 = VS 10.0 = Windows SDK 7
    # See: cmake --help-variable MSVC_VERSION
    # and https://developer.mozilla.org/en-US/docs/Windows_SDK_versions
    if (${MSVC_VERSION} LESS 1600)
        message(WARNING "Your MSVC version (${MSVC_VERSION}) is not supported. Please use the Windows SDK version 7 or later (or Microsoft Visual Studio 2010 or later).")
    endif()
elseif ("${CMAKE_CXX_COMPILER_ID}" STREQUAL "GNU")
    if (WIN32)
        _kde_compiler_min_version("4.7")
    elseif (APPLE)
        # FIXME: Apple heavily modifies GCC, so checking the
        # GCC version on OS/X is not very useful.
    else()
        _kde_compiler_min_version("4.5")
    endif()
elseif ("${CMAKE_CXX_COMPILER_ID}" STREQUAL "Clang")
    _kde_compiler_min_version("3.1")
else()
    message(WARNING "${CMAKE_CXX_COMPILER_ID} is not a supported C++ compiler.")
endif()



############################################################
# System API features
############################################################

# This macro is for adding definitions that affect the underlying
# platform API.  It makes sure that configure checks will also have
# the same defines, so that the checks match compiled code.
macro (_KDE_ADD_PLATFORM_DEFINITIONS)
    add_definitions(${ARGV})
    set(CMAKE_REQUIRED_DEFINITIONS ${CMAKE_REQUIRED_DEFINITIONS} ${ARGV})
endmacro()

if (UNIX)
    # Enable basically everything portable across modern UNIX systems.
    # See http://www.delorie.com/gnu/docs/glibc/libc_13.html, although
    # this define is for the benefit of other libc implementations
    # (since _GNU_SOURCE is defined below).
    _kde_add_platform_definitions(-D_XOPEN_SOURCE=500)

    # Enable everything in GNU libc.  Any code using non-portable features
    # needs to perform feature tests, but this ensures that any such features
    # will be found if they exist.
    #
    # NB: we do NOT define _BSD_SOURCE, as with GNU libc that requires linking
    # against the -lbsd-compat library (it changes the behaviour of some
    # functions).
    _kde_add_platform_definitions(-D_GNU_SOURCE)

    # Enable extra API for using 64-bit file offsets on 32-bit systems.
    # FIXME: this is included in _GNU_SOURCE in glibc; do other libc
    # implementation recognize it?
    _kde_add_platform_definitions(-D_LARGEFILE64_SOURCE)
endif()

if (WIN32)
    # Speeds up compile times by not including everything with windows.h
    # See http://msdn.microsoft.com/en-us/library/windows/desktop/aa383745%28v=vs.85%29.aspx
    _kde_add_platform_definitions(-DWIN32_LEAN_AND_MEAN)

    # Target Windows XP / Windows Server 2003
    # This enables various bits of new API
    # See http://msdn.microsoft.com/en-us/library/windows/desktop/aa383745%28v=vs.85%29.aspx
    _kde_add_platform_definitions(-D_WIN32_WINNT=0x0501 -DWINVER=0x0501 -D_WIN32_IE=0x0501)

    # Use the Unicode versions of Windows API by default
    # See http://msdn.microsoft.com/en-us/library/windows/desktop/dd317766%28v=vs.85%29.aspx
    _kde_add_platform_definitions(-DUNICODE)
endif()



############################################################
# Language and toolchain features
############################################################

# Pick sensible versions of the C and C++ standards.
# Note that MSVC does not have equivalent flags; the features are either
# supported or they are not.
if ("${CMAKE_C_COMPILER_ID}" STREQUAL "GNU" OR "${CMAKE_C_COMPILER_ID}" STREQUAL "Clang")
    # We use the C89 standard because that is what is common to all our
    # compilers (in particular, MSVC 2010 does not support C99)
    set(CMAKE_C_FLAGS   "${CMAKE_C_FLAGS} -std=iso9899:1990")
endif()
if ("${CMAKE_CXX_COMPILER_ID}" STREQUAL "GNU" OR "${CMAKE_CXX_COMPILER_ID}" STREQUAL "Clang")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c++0x")
elseif ("${CMAKE_CXX_COMPILER_ID}" STREQUAL "Intel" AND NOT WIN32)
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c++0x")
endif()

# Do not merge uninitialized global variables.
# This is mostly a "principle of least surprise" thing, but also
# has performance benefits.
# See https://www.ibm.com/developerworks/community/blogs/zTPF/entry/benefits_of_the_fnocommon_compile_option_peter_lemieszewski?lang=en
# Note that this only applies to C code; C++ already behaves like this.
if ("${CMAKE_C_COMPILER_ID}" STREQUAL "GNU" OR
        "${CMAKE_C_COMPILER_ID}" STREQUAL "Clang" OR
        ("${CMAKE_C_COMPILER_ID}" STREQUAL "Intel" AND NOT WIN32))
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -fno-common")
endif()

# Default to hidden visibility for symbols
set(CMAKE_CXX_VISIBILITY_PRESET hidden)
set(CMAKE_VISIBILITY_INLINES_HIDDEN 1)

if (UNIX AND NOT APPLE)
    # Enable adding DT_RUNPATH, which means that LD_LIBRARY_PATH takes precedence
    # over the built-in rPath
    set(CMAKE_SHARED_LINKER_FLAGS "-Wl,--enable-new-dtags ${CMAKE_SHARED_LINKER_FLAGS}")
    set(CMAKE_MODULE_LINKER_FLAGS "-Wl,--enable-new-dtags ${CMAKE_MODULE_LINKER_FLAGS}")
    set(CMAKE_EXE_LINKER_FLAGS    "-Wl,--enable-new-dtags ${CMAKE_EXE_LINKER_FLAGS}")
endif()

if (CMAKE_SYSTEM_NAME STREQUAL GNU)
    # Enable multithreading with the pthread library
    # FIXME: Is this actually necessary to have here?
    #        Can CMakeLists.txt files that require it use FindThreads.cmake
    #        instead?
    set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} -pthread")
    set(CMAKE_MODULE_LINKER_FLAGS "${CMAKE_MODULE_LINKER_FLAGS} -pthread")
endif()



############################################################
# Turn off exceptions by default
#
# This involves enough code to be separate from the
# previous section.
############################################################

# TODO: Deal with QT_NO_EXCEPTIONS for non-gnu compilers?
#       This should be defined if and only if exceptions are disabled.
#       qglobal.h has some magic to set it when exceptions are disabled
#       with gcc, but other compilers are unaccounted for.

# Turn off exceptions by default
if("${CMAKE_CXX_COMPILER_ID}" STREQUAL "GNU")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fno-exceptions")
#elseif("${CMAKE_CXX_COMPILER_ID}" STREQUAL "Clang")
    # Note that exceptions are enabled by default when building with clang. That
    # is, -fno-exceptions is not set in CMAKE_CXX_FLAGS below. This is because a
    # lot of code in different KDE modules ends up including code that throws
    # exceptions. Most (or all) of the occurrences are in template code that
    # never gets instantiated. Contrary to GCC, ICC and MSVC, clang (most likely
    # rightfully) complains about that. Trying to work around the issue by
    # passing -fdelayed-template-parsing brings other problems, as noted in
    # http://lists.kde.org/?l=kde-core-devel&m=138157459706783&w=2.
    # The generated code will be slightly bigger, but there is no way to avoid
    # it.
elseif ("${CMAKE_CXX_COMPILER_ID}" STREQUAL "Intel" AND NOT WIN32)
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fno-exceptions")
#elseif (MSVC OR (WIN32 AND "${CMAKE_CXX_COMPILER_ID}" STREQUAL "Intel"))
    # Exceptions appear to be disabled by default for MSVC
    # http://msdn.microsoft.com/en-us/library/1deeycx5.aspx

    # FIXME: are exceptions disabled by default for Intel?
endif()

macro(_kdecompilersettings_append_exception_flag VAR)
    if (MSVC)
        set(${VAR} "${${VAR}} -EHsc")
    elseif ("${CMAKE_CXX_COMPILER_ID}" STREQUAL "Intel")
        if (WIN32)
            set(${VAR} "${${VAR}} -EHsc")
        else()
            set(${VAR} "${${VAR}} -fexceptions")
        endif()
    elseif("${CMAKE_CXX_COMPILER_ID}" STREQUAL "GNU")
        set(${VAR} "${${VAR}} -fexceptions")
    elseif("${CMAKE_CXX_COMPILER_ID}" STREQUAL "Clang")
        # We never disabled exceptions for Clang anyway, but this makes it
        # blindingly obvious to anyone building with make VERBOSE=1
        set(${VAR} "${${VAR}} -fexceptions")
    endif()
    string(STRIP "${${VAR}}" ${VAR})
endmacro()

function(KDE_SOURCE_FILES_ENABLE_EXCEPTIONS)
    foreach(source_file ${ARGV})
        get_source_file_property(flags ${source_file} COMPILE_FLAGS)
        if(NOT flags)
            # If COMPILE_FLAGS is not set, get_source_file_property() sets it to
            # NOTFOUND, which breaks build if we concatenate anything to
            # the "NOTFOUND" string.
            # Note that NOTFOUND evaluates to False, so we do enter the if.
            set(flags "")
        endif()
        _kdecompilersettings_append_exception_flag(flags)
        set_source_files_properties(${source_file} COMPILE_FLAGS "${flags}")
    endforeach()
endfunction()

function(KDE_TARGET_ENABLE_EXCEPTIONS target mode)
    target_compile_options(${target} ${mode} "$<$<CXX_COMPILER_ID:MSVC>:-EHsc>")
    if (WIN32)
        target_compile_options(${target} ${mode} "$<$<CXX_COMPILER_ID:Intel>:-EHsc>")
    else()
        target_compile_options(${target} ${mode} "$<$<CXX_COMPILER_ID:Intel>:-fexceptions>")
    endif()
    # We never disabled exceptions for Clang anyway, but this makes it
    # blindingly obvious to anyone building with make VERBOSE=1
    target_compile_options(${target} ${mode}
        "$<$<OR:$<CXX_COMPILER_ID:GNU>,$<CXX_COMPILER_ID:Clang>>:-fexceptions>")
endfunction()

function(KDE_ENABLE_EXCEPTIONS)
    # We set CMAKE_CXX_FLAGS, rather than add_compile_options(), because
    # we only want to affect the compilation of C++ source files.

    # strip any occurrences of -DQT_NO_EXCEPTIONS; this should only be defined
    # if exceptions are disabled
    # the extra spaces mean we will not accentially mangle any other options
    string(REPLACE " -DQT_NO_EXCEPTIONS " " " CMAKE_CXX_FLAGS " ${CMAKE_CXX_FLAGS} ")
    # this option is common to several compilers, so just always remove it
    string(REPLACE " -fno-exceptions " " " CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS}")
    # strip undoes the extra spaces we put in above
    string(STRIP "${CMAKE_CXX_FLAGS}" CMAKE_CXX_FLAGS)

    _kdecompilersettings_append_exception_flag(CMAKE_CXX_FLAGS)
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS}" PARENT_SCOPE)
endfunction()



############################################################
# Better diagnostics (warnings, errors)
############################################################

if ("${CMAKE_CXX_COMPILER_ID}" STREQUAL "GNU" OR
        "${CMAKE_CXX_COMPILER_ID}" STREQUAL "Clang" OR
        ("${CMAKE_CXX_COMPILER_ID}" STREQUAL "Intel" AND NOT WIN32))
    # Linker warnings should be treated as errors
    set(CMAKE_SHARED_LINKER_FLAGS "-Wl,--fatal-warnings ${CMAKE_SHARED_LINKER_FLAGS}")
    set(CMAKE_MODULE_LINKER_FLAGS "-Wl,--fatal-warnings ${CMAKE_MODULE_LINKER_FLAGS}")

    # Do not allow undefined symbols, even in non-symbolic shared libraries
    set(CMAKE_SHARED_LINKER_FLAGS "-Wl,--no-undefined ${CMAKE_SHARED_LINKER_FLAGS}")
    set(CMAKE_MODULE_LINKER_FLAGS "-Wl,--no-undefined ${CMAKE_MODULE_LINKER_FLAGS}")
endif()

set(_KDE_GCC_COMMON_WARNING_FLAGS "-Wall -Wextra -Wcast-align -Wchar-subscripts -Wformat-security -Wno-long-long -Wpointer-arith -Wundef")
if("${CMAKE_C_COMPILER_ID}" STREQUAL "GNU" OR "${CMAKE_C_COMPILER_ID}" STREQUAL "Clang")
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} ${_KDE_GCC_COMMON_WARNING_FLAGS} -Wmissing-format-attribute -Wwrite-strings")
    # Make some warnings errors
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Werror=implicit-function-declaration")
endif()
if("${CMAKE_CXX_COMPILER_ID}" STREQUAL "GNU" OR "${CMAKE_CXX_COMPILER_ID}" STREQUAL "Clang")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${_KDE_GCC_COMMON_WARNING_FLAGS} -Wnon-virtual-dtor -Woverloaded-virtual")
    # Make some warnings errors
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Werror=return-type")
endif()

# -w1 turns on warnings and errors
# FIXME: someone needs to have a closer look at the Intel compiler options
if ("${CMAKE_C_COMPILER_ID}" STREQUAL "Intel" AND NOT WIN32)
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Wall -w1 -Wpointer-arith")
endif()
if ("${CMAKE_CXX_COMPILER_ID}" STREQUAL "Intel" AND NOT WIN32)
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wall -w1 -Wpointer-arith")
endif()

if (MSVC)
    # FIXME: do we not want to set the warning level up to level 3? (/W3)
    # Disable warnings:
    # C4250: 'class1' : inherits 'class2::member' via dominance
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} /wd4250")
    # C4251: 'identifier' : class 'type' needs to have dll-interface to be
    #        used by clients of class 'type2'
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} /wd4251")
    # C4396: 'identifier' : 'function' the inline specifier cannot be used
    #        when a friend declaration refers to a specialization of a
    #        function template
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} /wd4396")
    # C4661: 'identifier' : no suitable definition provided for explicit
    #         template instantiation request
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} /wd4661")
endif()

if (WIN32)
    # Disable deprecation warnings for some API
    # FIXME: do we really want this?
    add_definitions(-D_CRT_SECURE_NO_DEPRECATE
                    -D_CRT_SECURE_NO_WARNINGS
                    -D_CRT_NONSTDC_NO_DEPRECATE
                    -D_SCL_SECURE_NO_WARNINGS
                   )
endif()



############################################################
# Hacks
#
# Anything in this section should be thoroughly documented,
# including what problems it is supposed to fix and in what
# circumstances those problems occur.  Include links to any
# relevant bug reports.
############################################################

if (APPLE)
    # FIXME: why are these needed?
    set (CMAKE_SHARED_LINKER_FLAGS "-single_module -multiply_defined suppress ${CMAKE_SHARED_LINKER_FLAGS}")
    set (CMAKE_MODULE_LINKER_FLAGS "-multiply_defined suppress ${CMAKE_MODULE_LINKER_FLAGS}")
endif()

if (WIN32)
    if (MSVC OR (WIN32 AND "${CMAKE_CXX_COMPILER_ID}" STREQUAL "Intel"))
        # make sure that no header adds libcmt by default using
        # #pragma comment(lib, "libcmt.lib") as done by mfc/afx.h
        set(CMAKE_EXE_LINKER_FLAGS_RELEASE "/NODEFAULTLIB:libcmt /DEFAULTLIB:msvcrt ${CMAKE_EXE_LINKER_FLAGS_RELEASE}")
        set(CMAKE_EXE_LINKER_FLAGS_RELWITHDEBINFO "/NODEFAULTLIB:libcmt /DEFAULTLIB:msvcrt ${CMAKE_EXE_LINKER_FLAGS_RELWITHDEBINFO}")
        set(CMAKE_EXE_LINKER_FLAGS_MINSIZEREL "/NODEFAULTLIB:libcmt /DEFAULTLIB:msvcrt ${CMAKE_EXE_LINKER_FLAGS_MINSIZEREL}")
        # use the debug versions of the libraries for debug builds
        # if we just set /NODEFAULTLIB:libcmt /DEFAULTLIB:msvcrt unconditionally in CMAKE_EXE_LINKER_FLAGS we end up
        # linking to the debug and the release C runtime at the same time which will cause crashes
        set(CMAKE_EXE_LINKER_FLAGS_DEBUG "/NODEFAULTLIB:libcmtd /DEFAULTLIB:msvcrtd ${CMAKE_EXE_LINKER_FLAGS_DEBUG}")
    endif()
endif()

if (MINGW AND "${CMAKE_CXX_COMPILER_ID}" STREQUAL "GNU")
    # FIXME: do our export macros not deal with this properly?
    #        maybe we only need this for modules?
    set (CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} -Wl,--export-all-symbols")
    set (CMAKE_MODULE_LINKER_FLAGS "${CMAKE_MODULE_LINKER_FLAGS} -Wl,--export-all-symbols")
endif()


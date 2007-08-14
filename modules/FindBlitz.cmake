# - Try to find blitz lib
# Once done this will define
#
#  BLITZ_FOUND - system has blitz lib
#  BLITZ_INCLUDES - the blitz include directory
#  BLITZ_LIBRARIES - The libraries needed to use blitz
#
# Copyright (c) 2006, Montel Laurent, <montel@kde.org>
# Copyright (c) 2007, Allen Winter, <winter@kde.org>
# Redistribution and use is allowed according to the terms of the BSD license.
# For details see the accompanying COPYING-CMAKE-SCRIPTS file.

if (BLITZ_INCLUDES AND BLITZ_LIBRARIES)
  set(Blitz_FIND_QUIETLY TRUE)
endif (BLITZ_INCLUDES AND BLITZ_LIBRARIES)

find_path(BLITZ_INCLUDES
  NAMES
  blitz.h
  PATHS
  ${KDE4_INCLUDE_DIR}/blitz
  ${INCLUDE_INSTALL_DIR}/blitz
)

FIND_LIBRARY(BLITZ_LIBRARIES
 NAMES
 blitz
 PATHS
 ${KDE4_LIB_DIR}
 ${LIB_INSTALL_DIR}
)

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(Blitz DEFAULT_MSG 
                                  BLITZ_INCLUDES BLITZ_LIBRARIES)

mark_as_advanced(BLITZ_INCLUDES BLITZ_LIBRARIES)

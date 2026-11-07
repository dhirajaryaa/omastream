QT += core gui testlib

CONFIG += c++17 testcase
TARGET = omastream_tests
TEMPLATE = app

INCLUDEPATH += ../src

HEADERS += omastream_tests.h ../src/backend.h ../src/theme.h ../src/translator.h
SOURCES += omastream_tests.cpp ../src/backend.cpp ../src/theme.cpp ../src/translator.cpp

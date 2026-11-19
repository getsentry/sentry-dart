cmake_minimum_required(VERSION 3.14)
project(library_loader_fixture C)
add_library(slow_loader SHARED slow_loader.c)

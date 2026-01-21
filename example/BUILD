load("@rules_cc//cc:defs.bzl", "cc_library", "cc_binary")

cc_library(
    name = "lib",
    srcs = ["lib.cpp"],
    hdrs = ["lib.hpp"],
)

cc_library(
    name = "lib2",
    srcs = ["lib.c"],
    hdrs = ["lib.h"],
)

cc_library(
    name = "lib_ignored",
    srcs = ["lib_ignored.cpp"],
    hdrs = ["lib_ignored.hpp"],
    tags = ["no-clang-tidy"],
)

cc_binary(
    name = "example",
    srcs = ["app.cpp"],
    deps = [
        ":lib",
        ":lib_ignored",
    ],
)

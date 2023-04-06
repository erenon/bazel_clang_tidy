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

cc_binary(
    name = "example",
    srcs = ["app.cpp"],
    deps = [":lib"],
)

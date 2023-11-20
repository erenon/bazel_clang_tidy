load("@rules_proto//proto:defs.bzl", "proto_library")

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


# 1. With proto and cc_proto from rules_proto
# proto_library(
#     name = "person_proto",
#     srcs = ["person.proto"],
#     tags = ["no-clang-tidy"],
# )

# cc_proto_library(
#     name = "person_cc_proto",
#     deps = [":person_proto"],
#     tags = ["no-clang-tidy"],
# )

# 2. With cc_proto library from google protobuf, they are somehow not the same
load("@com_google_protobuf//:protobuf.bzl", "cc_proto_library")
cc_proto_library(
    name = "person_cc_proto",
    srcs = [":person.proto"],
    tags = ["no-clang-tidy"],
)

cc_binary(
    name = "example",
    srcs = ["app.cpp"],
    deps = [":lib", ":lib_ignored", ":person_cc_proto"],
)
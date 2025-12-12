load("@rules_cc//cc:defs.bzl", "cc_library", "cc_test")
load("//clang_tidy:clang_tidy_test.bzl", "clang_tidy_test")

# Abseil integration test
cc_library(
    name = "abseil_lib",
    srcs = ["abseil_test.cpp"],
    deps = [
        "@abseil-cpp//absl/strings",
        "@abseil-cpp//absl/container:flat_hash_map",
        "@abseil-cpp//absl/container:flat_hash_set",
    ],
)

clang_tidy_test(
    name = "abseil_clang_tidy_test",
    srcs = ["abseil_test.cpp"],
    deps = [
        "@abseil-cpp//absl/strings",
        "@abseil-cpp//absl/container:flat_hash_map",
        "@abseil-cpp//absl/container:flat_hash_set",
    ],
)

# GoogleTest integration test
cc_test(
    name = "gtest_example_test",
    srcs = ["gtest_example.cpp"],
    deps = [
        "@abseil-cpp//absl/strings",
        "@googletest//:gtest",
        "@googletest//:gtest_main",
    ],
)

clang_tidy_test(
    name = "gtest_clang_tidy_test",
    srcs = ["gtest_example.cpp"],
    deps = [
        "@abseil-cpp//absl/strings",
        "@googletest//:gtest",
    ],
)

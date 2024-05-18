load("//clang_tidy:clang_tidy_test.bzl", "clang_tidy_test")

filegroup(
    name = "sources",
    srcs = glob([
        "*.hpp",
        "*.cpp",
    ]),
)

test_suite(
    name = "example_tests",
    tests = [
        ":check_files_test",
        ":cc_test_example",
    ],
)

clang_tidy_test(
    name = 'check_files_test',
    srcs = [
        ":sources"
    ],
)

cc_test(
    name = "cc_test_example",
    visibility = ["//visibility:public"],
    srcs = [
       ":sources"
    ],
)


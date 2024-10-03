load("@bazel_skylib//rules:common_settings.bzl", "bool_flag")

filegroup(
    name = "clang_tidy_config_default",
    srcs = [
        ".clang-tidy",
        # '//example:clang_tidy_config', # add package specific configs if needed
    ],
)

label_flag(
    name = "clang_tidy_config",
    build_setting_default = ":clang_tidy_config_default",
    visibility = ["//visibility:public"],
)

filegroup(
    name = "clang_tidy_executable_default",
    srcs = [],  # empty list: system clang-tidy
)

label_flag(
    name = "clang_tidy_executable",
    build_setting_default = ":clang_tidy_executable_default",
    visibility = ["//visibility:public"],
)

filegroup(
    name = "clang_tidy_additional_deps_default",
    srcs = [],
)

label_flag(
    name = "clang_tidy_additional_deps",
    build_setting_default = ":clang_tidy_additional_deps_default",
    visibility = ["//visibility:public"],
)

bool_flag(
    name = "clang_tidy_bazel_out_includes_are_system_includes",
    build_setting_default = False,
    visibility = ["//visibility:public"],
)

bool_flag(
    name = "clang_tidy_virtual_includes_are_system_includes",
    build_setting_default = False,
    visibility = ["//visibility:public"],
)

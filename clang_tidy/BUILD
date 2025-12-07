load("@rules_shell//shell:sh_binary.bzl", "sh_binary")

sh_binary(
    name = "clang_tidy",
    srcs = ["run_clang_tidy.sh"],
    data = ["//:clang_tidy_config"],
    visibility = ["//visibility:public"],
)

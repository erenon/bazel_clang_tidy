sh_binary(
    name = "clang_tidy",
    srcs = ["run_clang_tidy.sh"],
    data = ["//:clang_tidy_config"],
    visibility = ["//visibility:public"],
)

filegroup(
    name = "apply_fixes_template",
    srcs = ["apply_fixes.template.sh"],
    visibility = ["//visibility:public"],
)

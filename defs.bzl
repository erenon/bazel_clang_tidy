"""
clang-tidy fix rule
"""

def _clang_tidy_apply_fixes_impl(ctx):
    apply_fixes = ctx.actions.declare_file(
        "clang_tidy.{}.sh".format(ctx.attr.name),
    )

    config = ctx.attr._tidy_config.files.to_list()
    if len(config) != 1:
        fail(":config ({}) must contain a single file".format(config))

    apply_bin = ctx.attr._apply_replacements_binary.files_to_run.executable
    apply_path = apply_bin.path if apply_bin else "clang-apply-replacements"

    ctx.actions.expand_template(
        template = ctx.attr._template.files.to_list()[0],
        output = apply_fixes,
        substitutions = {
            "@APPLY_REPLACEMENTS_BINARY@": apply_path,
            "@TIDY_BINARY@": str(ctx.attr._tidy_binary.label),
            "@TIDY_CONFIG@": str(ctx.attr._tidy_config.label),
            "@WORKSPACE@": ctx.label.workspace_name,
        },
    )

    return [
        DefaultInfo(executable = apply_fixes),
        # support use of a .bazelrc config containing `--output_groups=report`
        # for example, bazel run @bazel_clang_tidy//:apply_fixes --config=clang-tidy ...
        # with
        # build:clang-tidy --aspects @bazel_clang_tidy...
        # build:clang-tidy --@bazel_clang_tidy//:clang_tidy_config=...
        # build:clang-tidy --output_groups=report
        OutputGroupInfo(report = depset(direct = [apply_fixes])),
    ]

clang_tidy_apply_fixes = rule(
    implementation = _clang_tidy_apply_fixes_impl,
    fragments = ["cpp"],
    attrs = {
        "_template": attr.label(default = Label("//clang_tidy:apply_fixes_template")),
        "_tidy_config": attr.label(default = Label("//:clang_tidy_config")),
        "_tidy_binary": attr.label(default = Label("//:clang_tidy_executable")),
        "_apply_replacements_binary": attr.label(
            default = Label("//:clang_apply_replacements_executable"),
        ),
    },
    toolchains = ["@bazel_tools//tools/cpp:toolchain_type"],
    executable = True,
)

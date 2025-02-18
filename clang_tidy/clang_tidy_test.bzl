"""A test rule to run clang-tidy

NOTE: This rule requires bash
"""

load("@bazel_tools//tools/build_defs/cc:action_names.bzl", "ACTION_NAMES")
load("@bazel_tools//tools/cpp:toolchain_utils.bzl", "find_cpp_toolchain")
load(":clang_tidy.bzl", "deps_flags", "is_c_translation_unit", "rule_sources", "safe_flags", "toolchain_flags")

def _quote(s):
    # Copied from https://github.com/bazelbuild/bazel-skylib/blob/main/lib/shell.bzl
    return "'" + s.replace("'", "'\\''") + "'"

# Tests run with a different directory structure than normal compiles. This
# fixes up include paths or any other arguments that are sensitive to this
def _fix_argument_path(ctx, arg):
    return arg.replace(ctx.bin_dir.path, ".")

def _get_copts_attr(ctx, copts_attr):
    copts = []
    for copt in getattr(ctx.attr, copts_attr):
        copts.append(ctx.expand_make_variables(
            copts_attr,
            copt,
            {},
        ))

    return copts

def _clang_tidy_rule_impl(ctx):
    clang_tidy = ctx.attr.clang_tidy_executable
    clang_tidy_executable = clang_tidy[DefaultInfo].files_to_run.executable

    ccinfo_copts, additional_files = deps_flags(ctx, ctx.attr.deps)

    include_headers = "no-clang-tidy-headers" not in ctx.attr.tags
    srcs = rule_sources(ctx.attr, include_headers)

    rule_copts = _get_copts_attr(ctx, "copts")
    rule_conlyopts = _get_copts_attr(ctx, "conlyopts")
    rule_cxxopts = _get_copts_attr(ctx, "cxxopts")

    c_flags = safe_flags(toolchain_flags(ctx, ACTION_NAMES.c_compile) + rule_copts + rule_conlyopts) + ["-xc"]
    cxx_flags = safe_flags(toolchain_flags(ctx, ACTION_NAMES.cpp_compile) + rule_copts + rule_cxxopts) + ["-xc++"]

    ctx.actions.write(
        output = ctx.outputs.executable,
        is_executable = True,
        content = """\
#!/usr/bin/env bash

set -euo pipefail

readonly bin="{clang_tidy_bin}"
readonly config="{clang_tidy_config}"

test -e .clang-tidy || ln -s -f \\$config .clang-tidy
if [[ ! -f .clang-tidy ]]; then
  echo "error: failed to setup config" >&2
  exit 1
fi

ln -s .. external

has_srcs=false
if [[ -n "{c_sources}" ]]; then
  "$bin" --quiet --export-fixes $TEST_UNDECLARED_OUTPUTS_DIR/cfixes.yaml {c_sources} -- {c_flags}
  has_srcs=true
fi

if [[ -n "{cxx_sources}" ]]; then
  "$bin" --quiet --export-fixes $TEST_UNDECLARED_OUTPUTS_DIR/cxxfixes.yaml {cxx_sources} -- {cxx_flags}
  has_srcs=true
fi

if [[ "$has_srcs" == "false" ]]; then
  echo "error: no sources to run clang-tidy on" >&2
  exit 1
fi
""".format(
            clang_tidy_bin = clang_tidy_executable.short_path if clang_tidy_executable else "clang-tidy",
            clang_tidy_config = ctx.file.clang_tidy_config.short_path,
            output = ctx.outputs.executable.path,
            c_sources = " ".join([x.short_path for x in srcs if is_c_translation_unit(x, ctx.attr.tags)]),
            cxx_sources = " ".join([x.short_path for x in srcs if not is_c_translation_unit(x, ctx.attr.tags)]),
            c_flags = " ".join([_quote(_fix_argument_path(ctx, x)) for x in ccinfo_copts + c_flags]),
            cxx_flags = " ".join([_quote(_fix_argument_path(ctx, x)) for x in ccinfo_copts + cxx_flags]),
        ),
    )

    return [
        DefaultInfo(
            executable = ctx.outputs.executable,
            runfiles = ctx.runfiles(
                ctx.files.srcs + ctx.files.hdrs + ctx.files.data,
                transitive_files = depset(
                    [ctx.file.clang_tidy_config],
                    transitive = [additional_files, find_cpp_toolchain(ctx).all_files, ctx.attr.clang_tidy_additional_deps.files],
                ),
            )
                .merge(clang_tidy[DefaultInfo].default_runfiles),
        ),
    ]

clang_tidy_test = rule(
    implementation = _clang_tidy_rule_impl,
    test = True,
    fragments = ["cpp"],
    attrs = {
        "deps": attr.label_list(providers = [CcInfo]),
        "clang_tidy_executable": attr.label(default = Label("//:clang_tidy_executable")),
        "clang_tidy_additional_deps": attr.label(default = Label("//:clang_tidy_additional_deps")),
        "clang_tidy_config": attr.label(
            default = Label("//:clang_tidy_config"),
            allow_single_file = True,
        ),
        "srcs": attr.label_list(allow_files = True),
        "hdrs": attr.label_list(allow_files = True),
        "data": attr.label_list(allow_files = True),
        "copts": attr.string_list(),
        "conlyopts": attr.string_list(),
        "cxxopts": attr.string_list(),
    },
    toolchains = ["@bazel_tools//tools/cpp:toolchain_type"],
)

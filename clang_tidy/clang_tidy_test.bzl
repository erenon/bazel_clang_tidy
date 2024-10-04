load("@bazel_tools//tools/build_defs/cc:action_names.bzl", "ACTION_NAMES")
load("@bazel_tools//tools/cpp:toolchain_utils.bzl", "find_cpp_toolchain")
load("clang_tidy.bzl", "safe_flags", "check_valid_file_type", "toolchain_flags", "rule_sources")

def _clang_tidy_rule_impl(ctx):
    wrapper = ctx.attr.clang_tidy_wrapper.files.to_list()[0]
    exe = ctx.attr.clang_tidy_executable
    additional_deps = ctx.attr.clang_tidy_additional_deps
    config = ctx.attr.clang_tidy_config.files.to_list()[0]

    c_flags = safe_flags(toolchain_flags(ctx, ACTION_NAMES.c_compile)) + ["-xc"]
    cxx_flags = safe_flags(toolchain_flags(ctx, ACTION_NAMES.cpp_compile)) + ["-xc++"]
    flags = cxx_flags

    # Declare symlinks
    clang_tidy_config = ctx.actions.declare_file(config.basename)
    clang_tidy = ctx.actions.declare_file("run_clang_tidy.sh")

    args = []
    srcs = rule_sources(ctx, ctx.attr)

    # specify the output file - twice
    outfile = ctx.actions.declare_file(
        "bazel_clang_tidy_.clang-tidy.yaml",
    )
    ctx.actions.write(outfile, "")

    # this is consumed by the wrapper script
    if len(exe.files.to_list()) == 0:
        args.append("clang-tidy")
    else:
        args.append(exe.files_to_run.executable.basename)

    args.append(outfile.basename)  # this is consumed by the wrapper script

    # Configure clang-tidy config file
    ctx.actions.symlink(output = clang_tidy_config, target_file = config)
    args.append(clang_tidy_config.short_path)

    args.append("--export-fixes " + outfile.basename)

    # Configure clang-tidy script
    ctx.actions.symlink(output = clang_tidy, target_file = wrapper)

    # Add files to analyze
    for src in srcs:
        args.append(src.short_path)

    # add args specified by the toolchain, on the command line and rule copts
    if ctx.attr.use_flags:
        # start args passed to the compiler
        args.append("--")
        for flag in flags:
            args.append(flag)

    ctx.actions.write(
        output = ctx.outputs.executable,
        content = "./{binary} {args}".format(
            binary = clang_tidy.short_path,
            args = " ".join(args),
        ),
        is_executable = True,
    )
    # Setup runfiles
    runfiles = ctx.runfiles(files = srcs + [clang_tidy, clang_tidy_config])
    runfiles_basefolder = runfiles.files.to_list()[0].dirname
    return DefaultInfo(runfiles = runfiles)

clang_tidy_test = rule(
    implementation = _clang_tidy_rule_impl,
    test = True,
    fragments = ["cpp"],
    attrs = {
        'deps' : attr.label_list(),
        "cc_toolchain": attr.label(default = Label("@bazel_tools//tools/cpp:current_cc_toolchain")),
        "clang_tidy_wrapper": attr.label(default = Label("//clang_tidy:clang_tidy")),
        "clang_tidy_executable": attr.label(default = Label("//:clang_tidy_executable")),
        "clang_tidy_additional_deps": attr.label(default = Label("//:clang_tidy_additional_deps")),
        "clang_tidy_config": attr.label(default = Label("//:clang_tidy_config")),
        'srcs' : attr.label_list(allow_files = True),
        'hdrs' : attr.label_list(allow_files = True),
        'use_flags': attr.bool(default = True),
    },
    toolchains = ["@bazel_tools//tools/cpp:toolchain_type"],
)

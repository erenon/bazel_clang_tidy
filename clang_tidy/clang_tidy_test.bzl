load("@bazel_tools//tools/build_defs/cc:action_names.bzl", "ACTION_NAMES")
load("@bazel_tools//tools/cpp:toolchain_utils.bzl", "find_cpp_toolchain")

def _rule_sources(ctx):
    srcs = []
    if hasattr(ctx.attr, "srcs"):
        for src in ctx.attr.srcs:
            srcs += [src for src in src.files.to_list() if src.is_source and _check_valid_file_type(src)]
    if hasattr(ctx.attr, "hdrs"):
        for hdr in ctx.attr.hdrs:
            srcs += [hdr for hdr in hdr.files.to_list() if hdr.is_source and _check_valid_file_type(hdr)]
    return srcs
def _toolchain_flags(ctx, action_name = ACTION_NAMES.cpp_compile):
    cc_toolchain = find_cpp_toolchain(ctx)
    feature_configuration = cc_common.configure_features(
        ctx = ctx,
        cc_toolchain = cc_toolchain,
    )
    compile_variables = cc_common.create_compile_variables(
        feature_configuration = feature_configuration,
        cc_toolchain = cc_toolchain,
        user_compile_flags = ctx.fragments.cpp.cxxopts + ctx.fragments.cpp.copts,
    )
    flags = cc_common.get_memory_inefficient_command_line(
        feature_configuration = feature_configuration,
        action_name = action_name,
        variables = compile_variables,
    )
    return flags
def _safe_flags(flags):
    # Some flags might be used by GCC, but not understood by Clang.
    # Remove them here, to allow users to run clang-tidy, without having
    # a clang toolchain configured (that would produce a good command line with --compiler clang)
    unsupported_flags = [
        "-fno-canonical-system-headers",
        "-fstack-usage",
    ]

    return [flag for flag in flags if flag not in unsupported_flags]
def _check_valid_file_type(src):
    """
    Returns True if the file type matches one of the permitted srcs file types for C and C++ header/source files.
    """
    permitted_file_types = [
        ".c", ".cc", ".cpp", ".cxx", ".c++", ".C", ".h", ".hh", ".hpp", ".hxx", ".inc", ".inl", ".H",
    ]
    for file_type in permitted_file_types:
        if src.basename.endswith(file_type):
            return True
    return False

def _clang_tidy_rule_impl(ctx):
    wrapper = ctx.attr.clang_tidy_wrapper.files.to_list()[0]
    exe = ctx.attr.clang_tidy_executable
    additional_deps = ctx.attr.clang_tidy_additional_deps
    config = ctx.attr.clang_tidy_config.files.to_list()[0]

    c_flags = _safe_flags(_toolchain_flags(ctx, ACTION_NAMES.c_compile)) + ["-xc"]
    cxx_flags = _safe_flags(_toolchain_flags(ctx, ACTION_NAMES.cpp_compile)) + ["-xc++"]
    flags = cxx_flags

    # Declare symlinks
    clang_tidy_config = ctx.actions.declare_file(config.basename)
    clang_tidy = ctx.actions.declare_file("run_clang_tidy.sh")

    args = []
    srcs = _rule_sources(ctx)

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

    # start args passed to the compiler
    args.append("--")

    # add args specified by the toolchain, on the command line and rule copts
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
    },
    toolchains = ["@bazel_tools//tools/cpp:toolchain_type"],
)

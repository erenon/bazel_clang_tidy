load("@bazel_tools//tools/cpp:toolchain_utils.bzl", "find_cpp_toolchain")

def _run_tidy(
        ctx,
        wrapper,
        exe,
        additional_deps,
        config,
        flags,
        compilation_context,
        infile,
        discriminator):
    inputs = depset(
        direct = (
            [infile, config] +
            additional_deps.files.to_list() +
            ([exe.files_to_run.executable] if exe.files_to_run.executable else [])
        ),
        transitive = [compilation_context.headers],
    )

    args = ctx.actions.args()

    # specify the output file - twice
    outfile = ctx.actions.declare_file(
        "bazel_clang_tidy_" + infile.path + "." + discriminator + ".clang-tidy.yaml",
    )

    # this is consumed by the wrapper script
    if len(exe.files.to_list()) == 0:
        args.add("clang-tidy")
    else:
        args.add(exe.files_to_run.executable)

    args.add(outfile.path)  # this is consumed by the wrapper script

    args.add(config.path)

    args.add("--export-fixes", outfile.path)

    # add source to check
    args.add(infile.path)

    # start args passed to the compiler
    args.add("--")

    # add args specified by the toolchain, on the command line and rule copts
    args.add_all(flags)

    # add defines
    for define in compilation_context.defines.to_list():
        args.add("-D" + define)

    for define in compilation_context.local_defines.to_list():
        args.add("-D" + define)

    # add includes
    for i in compilation_context.framework_includes.to_list():
        args.add("-F" + i)

    for i in compilation_context.includes.to_list():
        args.add("-I" + i)

    args.add_all(compilation_context.quote_includes.to_list(), before_each = "-iquote")

    args.add_all(compilation_context.system_includes.to_list(), before_each = "-isystem")

    ctx.actions.run(
        inputs = inputs,
        outputs = [outfile],
        executable = wrapper,
        arguments = [args],
        mnemonic = "ClangTidy",
        use_default_shell_env = True,
        progress_message = "Run clang-tidy on {}".format(infile.short_path),
    )
    return outfile

def _rule_sources(ctx):
    srcs = []
    if hasattr(ctx.rule.attr, "srcs"):
        for src in ctx.rule.attr.srcs:
            srcs += [src for src in src.files.to_list() if src.is_source]
    return srcs

def _toolchain_flags(ctx):
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
        action_name = "c++-compile",  # tools/build_defs/cc/action_names.bzl CPP_COMPILE_ACTION_NAME
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

    return [flag for flag in flags if flag not in unsupported_flags and not flag.startswith("--sysroot")]

def _clang_tidy_aspect_impl(target, ctx):
    # if not a C/C++ target, we are not interested
    if not CcInfo in target:
        return []

    wrapper = ctx.attr._clang_tidy_wrapper.files_to_run
    exe = ctx.attr._clang_tidy_executable
    additional_deps = ctx.attr._clang_tidy_additional_deps
    config = ctx.attr._clang_tidy_config.files.to_list()[0]
    toolchain_flags = _toolchain_flags(ctx)
    rule_flags = ctx.rule.attr.copts if hasattr(ctx.rule.attr, "copts") else []
    safe_flags = _safe_flags(toolchain_flags + rule_flags)
    compilation_context = target[CcInfo].compilation_context
    srcs = _rule_sources(ctx)
    outputs = [_run_tidy(ctx, wrapper, exe, additional_deps, config, safe_flags, compilation_context, src, target.label.name) for src in srcs]

    return [
        OutputGroupInfo(report = depset(direct = outputs)),
    ]

clang_tidy_aspect = aspect(
    implementation = _clang_tidy_aspect_impl,
    fragments = ["cpp"],
    attrs = {
        "_cc_toolchain": attr.label(default = Label("@bazel_tools//tools/cpp:current_cc_toolchain")),
        "_clang_tidy_wrapper": attr.label(default = Label("//clang_tidy:clang_tidy")),
        "_clang_tidy_executable": attr.label(default = Label("//:clang_tidy_executable")),
        "_clang_tidy_additional_deps": attr.label(default = Label("//:clang_tidy_additional_deps")),
        "_clang_tidy_config": attr.label(default = Label("//:clang_tidy_config")),
    },
    toolchains = ["@bazel_tools//tools/cpp:toolchain_type"],
)

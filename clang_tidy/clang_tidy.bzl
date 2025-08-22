load("@bazel_tools//tools/build_defs/cc:action_names.bzl", "ACTION_NAMES")
load("@bazel_tools//tools/cpp:toolchain_utils.bzl", "find_cpp_toolchain")
load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")

def _run_tidy(
        ctx,
        cc_toolchain,
        wrapper,
        exe,
        gcc_install_dir,
        resource_dir,
        additional_deps,
        config,
        flags,
        infile,
        discriminator,
        additional_files,
        additional_inputs):
    direct_inputs = (
        [infile, config] +
        additional_deps.files.to_list() +
        ([exe.files_to_run.executable] if exe.files_to_run.executable else [])
    )
    for additional_input in additional_inputs:
        direct_inputs.extend(additional_input.files.to_list())

    inputs = depset(
        direct = direct_inputs,
        transitive = [additional_files, cc_toolchain.all_files, resource_dir.files],
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

    if len(gcc_install_dir.files.to_list()) >= 2:
        fail("clang_tidy_gcc_install_dir must contain at most one directory")

    for dir in gcc_install_dir.files.to_list():
        args.add("--gcc-install-dir=%s" % dir.path)

    resource_dir_files = resource_dir.files.to_list()
    if resource_dir_files:
        directory = resource_dir_files[0].path.split("/include/")[0]
        args.add("-resource-dir", directory)

    ctx.actions.run(
        inputs = inputs,
        outputs = [outfile],
        executable = wrapper,
        arguments = [args] + flags,
        mnemonic = "ClangTidy",
        use_default_shell_env = True,
        progress_message = "Run clang-tidy on {}".format(infile.short_path),
    )
    return outfile

def rule_sources(attr, include_headers):
    header_extensions = (
        ".h",
        ".hh",
        ".hpp",
        ".hxx",
        ".inc",
        ".inl",
        ".H",
    )
    permitted_file_types = [
        ".c",
        ".cc",
        ".cpp",
        ".cxx",
        ".c++",
        ".C",
    ] + list(header_extensions)

    def check_valid_file_type(src):
        """
        Returns True if the file type matches one of the permitted srcs file types for C and C++ header/source files.
        """
        for file_type in permitted_file_types:
            if src.basename.endswith(file_type):
                return True
        return False

    srcs = []
    if hasattr(attr, "srcs"):
        for src in attr.srcs:
            srcs += [src for src in src.files.to_list() if src.is_source and check_valid_file_type(src)]
    if hasattr(attr, "hdrs"):
        for hdr in attr.hdrs:
            srcs += [hdr for hdr in hdr.files.to_list() if hdr.is_source and check_valid_file_type(hdr)]
    if include_headers:
        return srcs
    else:
        return [src for src in srcs if not src.basename.endswith(header_extensions)]

def toolchain_flags(ctx, cc_toolchain, action_name = ACTION_NAMES.cpp_compile):
    feature_configuration = cc_common.configure_features(
        ctx = ctx,
        cc_toolchain = cc_toolchain,
    )
    user_compile_flags = ctx.fragments.cpp.copts
    if action_name == ACTION_NAMES.cpp_compile:
        user_compile_flags.extend(ctx.fragments.cpp.cxxopts)
    elif action_name == ACTION_NAMES.c_compile and hasattr(ctx.fragments.cpp, "conlyopts"):
        user_compile_flags.extend(ctx.fragments.cpp.conlyopts)
    compile_variables = cc_common.create_compile_variables(
        feature_configuration = feature_configuration,
        cc_toolchain = cc_toolchain,
        user_compile_flags = user_compile_flags,
    )
    flags = cc_common.get_memory_inefficient_command_line(
        feature_configuration = feature_configuration,
        action_name = action_name,
        variables = compile_variables,
    )
    return flags

def deps_flags(ctx, deps):
    compilation_contexts = [dep[CcInfo].compilation_context for dep in deps]
    additional_files = depset(transitive = [
        compilation_context.headers
        for compilation_context in compilation_contexts
    ])

    flags = []
    for compilation_context in compilation_contexts:
        # add defines
        for define in compilation_context.defines.to_list():
            flags.append("-D" + define)

        for define in compilation_context.local_defines.to_list():
            flags.append("-D" + define)

        # add includes
        for i in compilation_context.framework_includes.to_list():
            flags.append("-F" + i)

        for i in compilation_context.includes.to_list():
            flags.append("-I" + i)

        for i in compilation_context.quote_includes.to_list():
            flags.extend(["-iquote", i])

        for i in compilation_context.system_includes.to_list():
            flags.extend(["-isystem", i])

        for i in compilation_context.external_includes.to_list():
            flags.extend(["-isystem", i])

    return flags, additional_files

def safe_flags(flags):
    # Some flags might be used by GCC, but not understood by Clang.
    # Remove them here, to allow users to run clang-tidy, without having
    # a clang toolchain configured (that would produce a good command line with --compiler clang)
    unsupported_flags = [
        "-fno-canonical-system-headers",
        "-fstack-usage",
    ]

    return [flag for flag in flags if flag not in unsupported_flags]

def is_c_translation_unit(src, tags):
    """Judge if a source file is for C.

    Args:
        src(File): Source file object.
        tags(list[str]): Tags attached to the target.

    Returns:
        bool: Whether the source is for C.
    """
    if "clang-tidy-is-c-tu" in tags:
        return True

    return src.extension == "c"

def _clang_tidy_aspect_impl(target, ctx):
    # if not a C/C++ target, we are not interested
    if not CcInfo in target:
        return []

    # Ignore external targets
    if target.label.workspace_root.startswith("external"):
        return []

    # Targets with specific tags will not be formatted
    ignore_tags = [
        "noclangtidy",
        "no-clang-tidy",
    ]

    for tag in ignore_tags:
        if tag in ctx.rule.attr.tags:
            return []

    wrapper = ctx.attr._clang_tidy_wrapper.files_to_run
    exe = ctx.attr._clang_tidy_executable
    gcc_install_dir = ctx.attr._clang_tidy_gcc_install_dir
    resource_dir = ctx.attr._clang_tidy_resource_dir
    additional_deps = ctx.attr._clang_tidy_additional_deps
    config = ctx.attr._clang_tidy_config.files.to_list()[0]

    deps = [target] + getattr(ctx.rule.attr, "implementation_deps", [])
    rule_flags, additional_files = deps_flags(ctx, deps)
    copts = ctx.rule.attr.copts if hasattr(ctx.rule.attr, "copts") else []
    for copt in copts:
        rule_flags.append(ctx.expand_make_variables(
            "copts",
            copt,
            {},
        ))

    cc_toolchain = find_cpp_toolchain(ctx)
    c_flags = safe_flags(toolchain_flags(ctx, cc_toolchain, ACTION_NAMES.c_compile) + rule_flags) + ["-xc"]
    cxx_flags = safe_flags(toolchain_flags(ctx, cc_toolchain, ACTION_NAMES.cpp_compile) + rule_flags) + ["-xc++"]

    include_headers = "no-clang-tidy-headers" not in ctx.rule.attr.tags
    run_on_headers = ctx.attr._run_on_headers[BuildSettingInfo].value
    if type(run_on_headers) == type(True):
       if not run_on_headers:
          include_headers = False


    srcs = rule_sources(ctx.rule.attr, include_headers)

    outputs = [
        _run_tidy(
            ctx,
            cc_toolchain,
            wrapper,
            exe,
            gcc_install_dir,
            resource_dir,
            additional_deps,
            config,
            c_flags if is_c_translation_unit(src, ctx.rule.attr.tags) else cxx_flags,
            src,
            target.label.name,
            additional_files,
            additional_inputs = getattr(ctx.rule.attr, "additional_compiler_inputs", []),
        )
        for src in srcs
    ]

    return [
        OutputGroupInfo(report = depset(direct = outputs)),
    ]

clang_tidy_aspect = aspect(
    implementation = _clang_tidy_aspect_impl,
    fragments = ["cpp"],
    attr_aspects = ["implementation_deps"],
    attrs = {
        "_cc_toolchain": attr.label(default = Label("@bazel_tools//tools/cpp:current_cc_toolchain")),
        "_clang_tidy_wrapper": attr.label(default = Label("//clang_tidy:clang_tidy")),
        "_clang_tidy_executable": attr.label(default = Label("//:clang_tidy_executable")),
        "_clang_tidy_gcc_install_dir": attr.label(default = Label("//:clang_tidy_gcc_install_dir")),
        "_clang_tidy_resource_dir": attr.label(default = Label("//:clang_tidy_resource_dir")),
        "_clang_tidy_additional_deps": attr.label(default = Label("//:clang_tidy_additional_deps")),
        "_clang_tidy_config": attr.label(default = Label("//:clang_tidy_config")),
        "_run_on_headers": attr.label(default = Label("//:run_on_headers")),
    },
    toolchains = ["@bazel_tools//tools/cpp:toolchain_type"],
)

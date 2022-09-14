load("@bazel_tools//tools/cpp:toolchain_utils.bzl", "find_cpp_toolchain")
load("@build_bazel_apple_support//lib:apple_support.bzl", "apple_support")
load("@bazel_skylib//lib:dicts.bzl", "dicts")

def _run_tidy(ctx, exe, flags, compilation_context, infile, discriminator):
    inputs = depset(direct = [infile], transitive = [compilation_context.headers])

    args = ctx.actions.args()

    # specify the output file - twice
    outfile = ctx.actions.declare_file(
        "bazel_clang_tidy_" + infile.path + "." + discriminator + ".clang-tidy.yaml"
    )

    args.add(outfile.path)  # this is consumed by the wrapper script
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
        executable = exe,
        arguments = [args],
        mnemonic = "ClangTidy",
        progress_message = "Run clang-tidy on {}".format(infile.short_path),
        execution_requirements = {
            # without "no-sandbox" flag the clang-tidy can not find a .clang-tidy file in the
            # closest parent, because the .clang-tidy file is placed in a "clang_tidy" shell
            # script runfiles, which is not a parent directory for any C/C++ source file
            "no-sandbox": "1",
        },
    )
    return outfile

def _is_supported_extension(path):
    ext = path.rfind('.')
    if ext != -1:
       return path[ext:] in ['.c', '.cc', '.cpp', '.m', '.mm']
    return False

def _rule_sources(ctx):
    srcs = []
    if hasattr(ctx.rule.attr, "srcs"):
        for src in ctx.rule.attr.srcs:
            srcs += [src for src in src.files.to_list() if src.is_source and _is_supported_extension(src.path)]
    return srcs

def _toolchain_flags(ctx, action_name):
    cc_toolchain = find_cpp_toolchain(ctx)
    feature_configuration = cc_common.configure_features(
        ctx = ctx,
        cc_toolchain = cc_toolchain,
    )
    if action_name in ('c-compile', 'objc-compile'):
        user_compile_flags = ctx.fragments.cpp.copts
    elif action_name in ('c++-compile', 'objc++-compile'):
        user_compile_flags = ctx.fragments.cpp.copts + ctx.fragments.cpp.cxxopts
    else:
        fail('Unexpected action_name: %s' % action_name)

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

def _safe_flags(flags):
    # Some flags might be used by GCC, but not understood by Clang.
    # Remove them here, to allow users to run clang-tidy, without having
    # a clang toolchain configured (that would produce a good command line with --compiler clang)
    unsupported_flags = [
        "-fno-canonical-system-headers",
        "-fstack-usage",
    ]

    return [flag for flag in flags if flag not in unsupported_flags and not flag.startswith("--sysroot")]

def _get_flags_for_action(ctx, action_name):
  toolchain_flags = _toolchain_flags(ctx, action_name)
  rule_flags = ctx.rule.attr.copts if hasattr(ctx.rule.attr, "copts") else []
  safe_flags = _safe_flags(toolchain_flags + rule_flags)
  return safe_flags

def _clang_tidy_aspect_impl(target, ctx):
    # if not a C/C++ target, we are not interested
    if not CcInfo in target:
        return []

    # TODO: better way to do this?
    # tools/build_defs/cc/action_names.bzl CPP_COMPILE_ACTION_NAME
    c_flags = _get_flags_for_action(ctx, "c-compile")
    cpp_flags = _get_flags_for_action(ctx, "c++-compile")
    objc_flags = _get_flags_for_action(ctx, "objc-compile")
    objcpp_flags = _get_flags_for_action(ctx, "objc++-compile")
    flags_for_src = {
      '.c': c_flags,
      '.cpp': cpp_flags,
      '.cc': cpp_flags,
      '.m': objc_flags,
      '.mm': objcpp_flags,
    }
    def src_flags(src):
      for ext, flags in flags_for_src.items():
        if src.basename.endswith(ext):
          return flags
      fail('Unknown extension for %s!' % src.path)

    exe = ctx.attr._clang_tidy.files_to_run
    compilation_context = target[CcInfo].compilation_context
    srcs = _rule_sources(ctx)
    outputs = [_run_tidy(ctx, exe, src_flags(src), compilation_context, src, target.label.name) for src in srcs]

    return [
        OutputGroupInfo(report = depset(direct = outputs)),
    ]

clang_tidy_aspect = aspect(
    implementation = _clang_tidy_aspect_impl,
    fragments = ["cpp", "apple"],
    attrs = dicts.add(apple_support.action_required_attrs(), {
        "_cc_toolchain": attr.label(default = Label("@bazel_tools//tools/cpp:current_cc_toolchain")),
        "_clang_tidy": attr.label(default = Label("//clang_tidy:clang_tidy")),
    }),
    toolchains = ["@bazel_tools//tools/cpp:toolchain_type"],
)

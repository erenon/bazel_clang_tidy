load('@bazel_tools//tools/cpp:toolchain_utils.bzl', 'find_cpp_toolchain')
load('@rules_cc//cc:action_names.bzl', 'CPP_COMPILE_ACTION_NAME')

def _run_tidy(ctx, exe, flags, compilation_context, infile):
    args = ctx.actions.args()

    # specify the output file - twice
    outfile = ctx.actions.declare_file(infile.path + '.clang-tidy.yaml')
    args.add(outfile.path) # this is consumed by the wrapper script
    args.add('--export-fixes', outfile.path)

    # add source to check
    args.add(infile.path)

    # start args passed to the compiler
    args.add('--')

    # add args specified by the toolchain, on the command line and rule copts
    args.add_all(flags)

    # add defines
    for define in compilation_context.defines.to_list():
        args.add('-D' + define)

    for define in compilation_context.local_defines.to_list():
        args.add('-D' + define)

    # add includes
    for i in compilation_context.framework_includes.to_list():
        args.add('-F' + i)

    for i in compilation_context.includes.to_list():
        args.add('-I' + i)

    args.add_all(compilation_context.quote_includes.to_list(), before_each = '-iquote')

    args.add_all(compilation_context.system_includes.to_list(), before_each = '-isystem')

    ctx.actions.run(
        inputs = [infile],
        outputs = [outfile],
        executable = exe,
        arguments = [args],
        mnemonic = 'ClangTidy',
        progress_message = 'Run clang-tidy on {}'.format(infile.short_path),
        execution_requirements = {
            'no-sandbox': '1',
        }
    )
    return outfile

def _rule_sources(ctx):
    srcs = []
    if hasattr(ctx.rule.attr, 'srcs'):
        for src in ctx.rule.attr.srcs:
            srcs += src.files.to_list()
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
        action_name = CPP_COMPILE_ACTION_NAME,
        variables = compile_variables,
    )
    return flags

def _safe_flags(flags):
    # Some flags might be used by GCC, but not understood by Clang.
    # Remove them here, to allow users to run clang-tidy, without having
    # a clang toolchain configured (that would produce a good command line with --compiler clang)
    return [flag for flag in flags if flag != '-fno-canonical-system-headers']

def _clang_tidy_aspect_impl(target, ctx):
    # if not a C/C++ target, we are not interested
    if not CcInfo in target:
        return []

    exe = ctx.attr._clang_tidy.files_to_run
    toolchain_flags = _toolchain_flags(ctx)
    rule_flags = ctx.rule.attr.copts if hasattr(ctx.rule.attr, 'copts') else []
    safe_flags = _safe_flags(toolchain_flags + rule_flags)
    compilation_context = target[CcInfo].compilation_context
    srcs = _rule_sources(ctx)
    outputs = [_run_tidy(ctx, exe, safe_flags, compilation_context, src) for src in srcs]

    dep_outputs = [
        dep[OutputGroupInfo].report
        for dep in ctx.rule.attr.deps
        if OutputGroupInfo in dep
    ]

    return [
        OutputGroupInfo(report = depset(outputs, transitive = dep_outputs)),
    ]

clang_tidy_aspect = aspect(
    implementation = _clang_tidy_aspect_impl,
    attr_aspects = ['deps'],
    fragments = ['cpp'],
    attrs = {
        '_cc_toolchain': attr.label(default = Label('@bazel_tools//tools/cpp:current_cc_toolchain')),
        '_clang_tidy': attr.label(default = Label('//clang_tidy:clang_tidy')),
    },
)

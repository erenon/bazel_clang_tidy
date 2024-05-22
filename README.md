# bazel_clang_tidy

Run clang-tidy on Bazel C++ targets directly,
without generating a compile commands database,
and take advantage of Bazels powerful cache mechanism.

Usage:

```py
# //:WORKSPACE
load(
    "@bazel_tools//tools/build_defs/repo:git.bzl",
    "git_repository",
)

git_repository(
       name = "bazel_clang_tidy",
       commit = "43bef6852a433f3b2a6b001daecc8bc91d791b92",
       remote = "https://github.com/erenon/bazel_clang_tidy.git",
)
```

You can now compile using the default clang tidy configuration provided using
the following command;

```text
bazel build //... \
  --aspects @bazel_clang_tidy//clang_tidy:clang_tidy.bzl%clang_tidy_aspect \
  --output_groups=report
```

If you would like to override the default clang tidy configuration then you can
reconfigure the default target from the command line. To do this you must first
make a filegroup target that has the .clang-tidy config file as a data
dependency.

```py
# //:BUILD
filegroup(
       name = "clang_tidy_config",
       srcs = [".clang-tidy"],
       visibility = ["//visibility:public"],
)
```

Now you can override the default config file in this repository using
a command line flag;

```sh
bazel build //... \
  --aspects @bazel_clang_tidy//clang_tidy:clang_tidy.bzl%clang_tidy_aspect \
  --output_groups=report \
  --@bazel_clang_tidy//:clang_tidy_config=//:clang_tidy_config
```

:exclamation: the config-file will not be forced by adding it to the clang-tidy command line. Therefore it must be in one of the parents of all source files. It is recommended to put it in the root directly besides the WORKSPACE file.

Now if you don't want to type this out every time, it is recommended that you
add a config in your .bazelrc that matches this command line;

```text
# Required for bazel_clang_tidy to operate as expected
build:clang-tidy --aspects @bazel_clang_tidy//clang_tidy:clang_tidy.bzl%clang_tidy_aspect
build:clang-tidy --output_groups=report

# Optionally override the .clang-tidy config file target
build:clang-tidy --@bazel_clang_tidy//:clang_tidy_config=//:clang_tidy_config
```

Now from the command line this is a lot nicer to use;

```sh
bazel build //... --config clang-tidy
```

### Use clang_tidy_test rule

You cane use rule `clang_tidy_test` to test your files with clang-tidy.

Example code is located here: `example/cc_test_example`

You can run example with:

```sh
bazel test //example/cc_test_example:example_tests
```

This command is a `test_suite` for build and run your program and run clang-tidy on example files.

To define clang-tidy test you simply add this rule to your `BUILD` file:

```text
load("@bazel_clang_tidy//clang_tidy:clang_tidy_test.bzl", "clang_tidy_test")
clang_tidy_test(
    name = '<TEST_NAME>',
    srcs = [
        "a.hpp"
        "a.cpp"
    ],
)
```

In this rule, you can use the same arguments as in the aspect (they are public here - easier to set):

```text
'deps' : attr.label_list(),
"cc_toolchain": attr.label(default = Label("@bazel_tools//tools/cpp:current_cc_toolchain")),
"clang_tidy_wrapper": attr.label(default = Label("//clang_tidy:clang_tidy")),
"clang_tidy_executable": attr.label(default = Label("//:clang_tidy_executable")),
"clang_tidy_additional_deps": attr.label(default = Label("//:clang_tidy_additional_deps")),
"clang_tidy_config": attr.label(default = Label("//:clang_tidy_config")),
'srcs' : attr.label_list(allow_files = True),
'hdrs' : attr.label_list(allow_files = True),
'use_flags': attr.bool(default = True),
```

They can be set as follows:

```text
clang_tidy_test(
  name = "clang_tidy_test",
  clang_tidy_config = "//:clang_tidy_config",
  clang_tidy_additional_deps = "//:clang_tidy_additional_deps",
  srcs = [
    ":test_sources"
  ],
  deps = ["some_deps"],
  use_flags = False, # You want set this to false if you are using compile_commands.json
)
```

### use a non-system clang-tidy

by default, bazel_clang_tidy uses the system provided clang-tidy.
If you have a hermetic build, you can use your own clang-tidy target like this:

```text
build:clang-tidy --@bazel_clang_tidy//:clang_tidy_executable=@local_config_cc//:clangtidy_bin
```

This aspect is not executed on external targets. To exclude other targets,
users may tag a target with `no-clang-tidy` or `noclangtidy`.

## Features

- Run clang-tidy on any C++ target
- Run clang-tidy without also building the target
- Use Bazel to cache clang-tidy reports: recompute stale reports only

## Install

Copy `.clang-tidy`, `BUILD` and `clang_tidy` dir to your workspace.
Edit `.clang-tidy` as needed.

## Example

To see the tool in action:

1. Clone the repository
1. Run clang-tidy:

    ```sh
    bazel build //example:lib --aspects clang_tidy/clang_tidy.bzl%clang_tidy_aspect --output_groups=report
    ```

1. Check the error:

    ```text
    lib.cpp:4:43: error: the parameter 'name' is copied for each invocation but only used as a const reference; consider making it a const reference [performance-unnecessary-value-param,-warnings-as-errors] std::string lib_get_greet_for(std::string name)
    Aspect //clang_tidy:clang_tidy.bzl%clang_tidy_aspect of //example:app failed to build
    ```

1. Fix the error by changing `lib.cpp` only.
1. Re-run clang-tidy with the same command. Observe that it does not run clang-tidy for `app.cpp`: the cached report is re-used.

## Requirements

- Bazel 4.0 or newer (might work with older versions)

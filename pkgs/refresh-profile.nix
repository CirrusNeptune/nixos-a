{ writers }:
writers.writePython3Bin "refresh-profile" {
  flakeIgnore = [ "E501" ];
} ''
import os
import pathlib

ENV_VARS = [
    'PATH',
    'NIX_CFLAGS_COMPILE_FOR_BUILD',
    'NIX_CFLAGS_COMPILE',
    'NIX_LDFLAGS_FOR_BUILD',
    'NIX_LDFLAGS',
    'PKG_CONFIG_PATH_FOR_TARGET',
    'NIX_CC_WRAPPER_TARGET_HOST_x86_64_unknown_linux_gnu',
    'NIX_CC_WRAPPER_TARGET_BUILD_x86_64_unknown_linux_gnu',
    'NIX_BINTOOLS_WRAPPER_TARGET_BUILD_x86_64_unknown_linux_gnu',
    'NIX_BINTOOLS_WRAPPER_TARGET_HOST_x86_64_unknown_linux_gnu',
    'NIX_PKG_CONFIG_WRAPPER_TARGET_TARGET_x86_64_unknown_linux_gnu',
]


def get_bindgen_sys_args():
    import shutil
    arch = 'x86_64-unknown-linux-gnu'
    gcc_path = pathlib.Path(shutil.which(f'{arch}-gcc'))
    gcc_prefix = gcc_path.parent.parent
    gcc_prefix_str = str(gcc_prefix)
    last_idx = gcc_prefix_str.rfind('-')
    version = gcc_prefix_str[last_idx + 1:]
    gcc_rt_inc = gcc_prefix.joinpath(f'lib/gcc/{arch}/{version}/include')
    return f'-idirafter {gcc_rt_inc}'


home_dir = pathlib.Path(os.environ['HOME'])
with open(home_dir.joinpath('.bash_profile'), 'w') as f:
    f.write('#!/bin/sh\n\n')
    for key in ENV_VARS:
        if key in os.environ:
            val = os.environ[key]
            f.write(f'export {key}="{val}"\n\n')
    if 'NIX_CFLAGS_COMPILE' in os.environ:
        val = os.environ['NIX_CFLAGS_COMPILE']
        f.write(f'export BINDGEN_EXTRA_CLANG_ARGS="{get_bindgen_sys_args()} {val}"\n\n')
    try:
        with open(home_dir.joinpath('.bash_profile_extra'), 'r') as extra_f:
            extra = extra_f.read()
            f.write(extra)
    except FileNotFoundError:
        pass
''

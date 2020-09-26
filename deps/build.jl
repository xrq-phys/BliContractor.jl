# compile the lazy wrapper in C language.
#
using tblis_jll: tblis, tblis_path

# os compiler / library name switch.
global cc = ""
global dll = ""
if Sys.iswindows()
    global cc = "gcc" # default for MinGW provider.
    global dll = "dll"
elseif Sys.isapple()
    global cc = "gcc" # prefers gcc alias, which is the same as BLIS' config script.
    global dll = "dylib"
else # Sys.islinux(), which is the default.
    global cc = "gcc"
    global dll = "so"
end

# set path to the pointer-type wrapper.
dll_path = joinpath(@__DIR__, "../src/tblis_contract_lazy")
src_path = joinpath(@__DIR__, "../src/tblis_contract_lazy.c")

# find TBLIS build.
global tblis_dir = ""
if "TBLISDIR" in keys(ENV)
    global tblis_dir = ENV["TBLISDIR"]
    if length(tblis_dir) <= 0 || ~isdir(joinpath(tblis_dir, "include/tblis"))
        error("Invalid TBLIS installation specified by TBLISDIR.")
    end
    @info "Using user-specified TBLIS runtime in $tblis_dir."
else
    # use the tblis_jll vendored binary.
    global tblis_dir = dirname(dirname(tblis_path))
end

compile_cmd = ```
    $cc -fPIC -I$tblis_dir/include -I$tblis_dir/include/tblis -Wl,-rpath,$tblis_dir/lib -L$tblis_dir/lib -ltblis $src_path -shared -o $dll_path.$dll
```

# try to build C wrapper.
@info compile_cmd
run(  compile_cmd )


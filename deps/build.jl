# compile the lazy wrapper in C language.
#
using tblis_jll

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
# get compiler from environment.
if "CC" in keys(ENV)
    global cc = ENV["CC"]
end

# set path to the pointer-type wrapper.
dll_path = joinpath(@__DIR__, "../src/tblis_contract_lazy")
src_path = joinpath(@__DIR__, "../src/tblis_contract_lazy.c")

if Sys.isapple() && Sys.ARCH == :aarch64
    # Use external library instead.
    src_dir = joinpath(@__DIR__, "../src")
    lib_url = "https://github.com/xrq-phys/tblis/releases/download/v1.2.0%2Barm%2Bamx/libtblis_aarch64_apple_darwin.tar.gz"
    cd(src_dir)
    run(`bash -c "curl -L $lib_url > lib.tar.gz"`)
    run(`tar -zxvf lib.tar.gz`)
    ENV["TBLISDIR"] = src_dir
end

# find TBLIS build.
global tblis_dir = ""
global tblis_available = false
if "TBLISDIR" in keys(ENV)
    global tblis_dir = ENV["TBLISDIR"]
    global tblis_available = true
    if length(tblis_dir) <= 0 || ~isdir(joinpath(tblis_dir, "include/tblis"))
        error("Invalid TBLIS installation specified by TBLISDIR.")
    end
    @info "Using user-specified TBLIS runtime in $tblis_dir."
else
    # use the tblis_jll vendored binary.
    using tblis_jll: tblis, tblis_path

    global tblis_dir = dirname(dirname(tblis_path))
    global tblis_available = tblis_jll.is_available()
end

compile_cmd = ```
    $cc -fPIC -I$tblis_dir/include -I$tblis_dir/include/tblis -Wl,-rpath,$tblis_dir/lib -L$tblis_dir/lib -ltblis $src_path -ltblis -shared -o $dll_path.$dll
```

# try to build C wrapper.
if tblis_available
    @info compile_cmd
    run(  compile_cmd )
else
    @info "A valid TBLIS installation was not found. BliContractor.jl will not be available."
end

if Sys.isapple() && Sys.ARCH == :aarch64
    # Cleanup
    run(`rm -rf include lib.tar.gz`)
end


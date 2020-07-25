# os compiler / library name switch.
global cc = ""
global dll = ""
if Sys.iswindows()
    global cc = "cl"
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
else
    for dir in (homedir(), "/opt", "/usr/local", "/usr")
        if isdir(joinpath(dir, "include/tblis"))
            global tblis_dir = dir
            break
        end
    end
    if length(tblis_dir) <= 0
        error(string("A valid TBLIS installation was not found. Binary provided by ",
                     "tblis_jll is not good enough at the moment when this package ",
                     "was last updated. Please build it from source available from ",
                     "https://github.com/devinamatthews/tblis."))
    end
end
@info("Found TBLIS run-time in $tblis_dir.")

# try to build C wrapper.
@info("$cc -I$tblis_dir/include -I$tblis_dir/include/tblis $src_path -L$tblis_dir/lib -ltblis -shared -o $dll_path.$dll")
run(`$cc -I$tblis_dir/include -I$tblis_dir/include/tblis $src_path -L$tblis_dir/lib -ltblis -shared -o $dll_path.$dll`)


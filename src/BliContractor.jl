module BliContractor

using Libdl
using ForwardDiff: Dual, Partials

export contract, contract!

global dll_path = joinpath(dirname(pathof(BliContractor)), "tblis_contract_lazy")
global dll_obj = C_NULL

__init__() = begin
    global dll_obj = dlopen(dll_path)
end

include("contract_fwd.jl")

end


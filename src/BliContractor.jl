# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

module BliContractor

# feature switch, as constants.
const global enable_pullbacks = true
const global enable_mm_rules = true

using tblis_jll
using Libdl
using LinearAlgebra
using ForwardDiff: Dual, Partials
if enable_pullbacks
    using Zygote: @adjoint
end
import Base

export contract, contract!

global dll_path = joinpath(dirname(pathof(BliContractor)), "tblis_contract_lazy")
global dll_obj = C_NULL

is_available() = dll_obj != C_NULL

__init__() = begin
    # Cannot guarantee TBLIS is always available.
    try
        global dll_obj = dlopen(dll_path)
    catch dll_err
        if !occursin("could not load library", dll_err.msg)
            # Throw again the error.
            # Otherwise we treat the error as library unavailability.
            throw(dll_err)
        end
    end
end

include("contract_fwd.jl")
if enable_pullbacks
    include("contract_bak.jl")
end
if enable_mm_rules
    include("matrix_mul.jl")
end

end


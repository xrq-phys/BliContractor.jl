# Defines adjoint methods for Zygote.jl, with dual number compatibility.
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

# only non-mutating methods have adjoint.
# contract(Array, Array, String, String, String) automatically falls back.

@adjoint contract(A::StridedArray{T}, idxA::String, B::StridedArray{T}, idxB::String, idxC::String) where {T} = begin
    contract(A, idxA, B, idxB, idxC), C̄ -> begin
        # expand to arrays and null return.
        if C̄ isa Tuple
            C̄, = C̄
        end
        if C̄ isa Nothing
            return (nothing, nothing, nothing, nothing, nothing)
        end
        if !(C̄ isa StridedArray)
            C̄ = Array(C̄)
        end
        # any permutation of the idx{A,B,C} strings like:
        #   "i..k..", "j..k.." -> "i..j.."
        # defines a valid operation. e.g. 
        #   "i..j..", "j..k.." -> "i..k.."
        # note that conjugation is not considered here.
        Ā = contract(C̄, idxC, B, idxB, idxA)
        B̄ = contract(A, idxA, C̄, idxC, idxB)
        (Ā, nothing, B̄, nothing, nothing)
    end
end


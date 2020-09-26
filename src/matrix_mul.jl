# Override base methods for matrix of duals with TBLIS contraction.
# This should improve quite a bit the performance.
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

Base.:*(A::StridedMatrix{<:Dual}, B::StridedMatrix{<:Dual}) = contract(A, "ik", B, "kj", "ij")
# note that adjoint==transpose only for real cases.
Base.:*(A::Adjoint{<:Dual, <:StridedMatrix}, B::StridedMatrix{<:Dual}) = contract(A', "ki", B,  "kj", "ij")
Base.:*(A::StridedMatrix{<:Dual}, B::Adjoint{<:Dual, <:StridedMatrix}) = contract(A,  "ik", B', "jk", "ij")


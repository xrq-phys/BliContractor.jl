# Simple testsuite for BliContractor.
# TODO: Test for adjonits.
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
using Test
using BliContractor

for dtype in ( Float64, ComplexF64, Float32, ComplexF32 )
    for m in ( 20, 40, 80 )
        A = rand(dtype, m, m, m, m)
        B = rand(dtype, m, m, m)
        C = zeros(dtype, m, m, m)

        contract!(A, "mijn", B, "kmn", C, "ikj", 2, 0)
        err1 = sum(abs.(permutedims(reshape(reshape(permutedims(A, (2, 3, 1, 4)), (m*m, m*m)) *
                                            reshape(permutedims(B, (2, 3, 1)), (m*m, m)), (m, m, m)), (1, 3, 2)) - C ./ 2))
        @show err1
        @test err1 ≈ 0 atol=m^5*1e-5

        C = ones(dtype, m, m, m)

        wA = view(A, 1:2:m, 1:2:m, 1:2:m, 1:2:m)
        wB = view(B, 1:2:m, 1:2:m, 1:2:m)
        wC = view(C, 1:2:m, 1:2:m, 1:2:m)
        contract!(wA, "mijn", wB, "kmn", wC, "ikj", 1, 1)
        err2 = sum(abs.(permutedims(reshape(reshape(permutedims(wA, (2, 3, 1, 4)), (m*m÷4, m*m÷4)) *
                                            reshape(permutedims(wB, (2, 3, 1)), (m*m÷4, m÷2)), (m÷2, m÷2, m÷2)), (1, 3, 2)) - wC .+ 1))
        @show err2
        @test err2 ≈ 0 atol=m^5*1e-5
    end
end


# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

# Indices are in reverse of NHWC. i.e. CWHN since Julia is column-major.
#
using BliContractor

conv(imgA, kerB) = begin
    ci, w,  h,  n  = size(imgA)
    co, ci, wi, hi = size(kerB)
    wo = w - wi + 1
    ho = h - hi + 1

    outC = zeros(eltype(imgA), (co, wo, ho, n))
    conv!(outC, imgA, kerB)
end

conv!(outC, imgA, kerB) = begin
    ci, w,  h,  n  = size(imgA)
    co, ci, wi, hi = size(kerB)
    cs_a, ws_a, hs_a, bs_a = strides(imgA)
    os_b, is_b, ws_b, hs_b = strides(kerB)
    cs_c, ws_c, hs_c, bs_c = strides(outC)
    wo = w - wi + 1
    ho = h - hi + 1

    # Size check.
    size(outC) == (co, wo, ho, n) || throw(DimensionMismatch("Out buffer mismatch."))

    imgA_t = CustomStridedArray{eltype(imgA), 6}(imgA,
                                                 (n,    ho,   hi,   wo,   wi,   ci),
                                                 (bs_a, hs_a, hs_a, ws_a, ws_a, cs_a))
    kerB_t = CustomStridedArray{eltype(kerB), 4}(kerB,
                                                 (hi,   wi,   ci,   co),
                                                 (hs_b, ws_b, is_b, os_b))
    outC_t = CustomStridedArray{eltype(outC), 4}(outC,
                                                 (n,    ho,   wo,   co),
                                                 (bs_c, hs_c, ws_c, cs_c))
    # m_gemm = n * ho * wo
    # n_gemm = co
    # k_gemm = hi * wi * ci
    # @show m_gemm
    # @show n_gemm
    # @show k_gemm
    contract!(imgA_t, "nHhWwc", kerB_t, "hwcC", outC_t, "nHWC")
    outC
end


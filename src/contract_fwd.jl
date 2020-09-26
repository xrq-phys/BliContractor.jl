# This file defines contract interfaces for the forward pass (value and 
# differentials), as well as the final interface to contract_lazy wrapper.
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

# tovalue unveils base type of duals.
tovalue(::Type{<:Dual{Tg, T}}) where {Tg, T} = tovalue(T)
tovalue(T::Type{<:Union{Float32, Float64, ComplexF32, ComplexF64}}) = T


contract(A::StridedArray{T}, B::StridedArray{T}, idxA::String, idxB::String, idxC::String) where {T} = begin
    contract(A, idxA, B, idxB, idxC)
end

contract(A::StridedArray{T}, idxA::String, B::StridedArray{T}, idxB::String, idxC::String) where {T} = begin
    idxsize(idx::String, siz::NTuple) = begin
        if length(idx) != 0
            return Dict([(c, siz[i]) for (i, c)=enumerate(split(idx, ""))])
        else
            return Dict()
        end
    end
    # (unsafe) dimension lookup for A & B indices.
    dimsA = idxsize(idxA, size(A))
    dimsB = idxsize(idxB, size(B))
    merge!(dimsA, dimsB)
    # calculate final size of tensor C and allocate.
    if length(idxC) != 0
        szC = ([dimsA[c] for c=split(idxC, "")]..., )
    else
        # contract to a scalar.
        szC = ( )
    end
    C = zeros(T, szC...)
    # invoke the dispatch process.
    # TODO: test which is faster: β=true or β=false?
    contract!(A, idxA, B, idxB, C, idxC, true, false)
    # return result in allocated container.
    return C
end

"Entry of contraction. Here idx{A,B,C} are 3 entries corresponding to e.g. \"ik,jk->ij\"."
contract!(A::StridedArray{T}, idxA::String,
          B::StridedArray{T}, idxB::String,
          C::StridedArray{T}, idxC::String, α=true, β=false) where {T} = begin
    contract!(T, sizeof(T)÷sizeof(tovalue(T)),
              A, 0, idxA, B, 0, idxB, C, 0, idxC, α, β)
end

# Dispatch w.r.t. elements with top stride (topst) and view shifts (sft[ABC])
# defined outside A, B and C. This somehow disgraceful style is because Julia
# cannot convert view(reinterpret(view)) into a StridedArray even when the 
# actual memory layout is strided.

"Dispatcher for Dual types of ForwardDiff.jl."
contract!(::Type{<:Dual{Tg, T, ND}}, topst::Int64, # top-level stride
          A::StridedArray, sftA::Int64, idxA::String, # arrays here are all at their top-level (not dispatched)
          B::StridedArray, sftB::Int64, idxB::String,
          C::StridedArray, sftC::Int64, idxC::String, α, β) where {Tg, T, ND} = begin
    # direct dispatch for value types.
    contract!(T, topst, A, sftA, idxA, B, sftB, idxB, C, sftC, idxC, α, β)

    # for all differentials
    # TODO: consider exchangability
    for id = 1:ND
        # unpacks one layer of dual. note that differentials are also in value's type.
        contract!(T, topst,
                  A, sftA + id*sizeof(T), idxA,
                  B, sftB,                idxB,
                  C, sftC + id*sizeof(T), idxC, α, 1)
        contract!(T, topst,
                  A, sftA,                idxA,
                  B, sftB + id*sizeof(T), idxB,
                  C, sftC + id*sizeof(T), idxC, α, 1)
    end
end

# These are final dispatchers for plain numbers.
# Implement s/d/c/z, corresponding to tblis_contract_lazy.c.

macro tblis_contract_sym(typename, typechar)
    ccfunc = Expr(:string, string("tblis_contract_", typechar))
    jlfunc = :( contract! )
    return quote
        $(esc(jlfunc))(::Type{<:$typename}, topst::Int64,
                       A::StridedArray, sftA::Int64, idxA::String,
                       B::StridedArray, sftB::Int64, idxB::String,
                       C::StridedArray, sftC::Int64, idxC::String, α, β) = begin
        $(esc(jlfunc))(dlsym(dll_obj, $(esc(ccfunc))), topst,
                       A, sftA, idxA,
                       B, sftB, idxB,
                       C, sftC, idxC, $typename(α), $typename(β));
        end
    end
end

@tblis_contract_sym Float32    s
@tblis_contract_sym Float64    d
@tblis_contract_sym ComplexF32 c
@tblis_contract_sym ComplexF64 z

contract!(contract_lazy::Ptr, topst::Int64,
          A::StridedArray, sftA::Int64, idxA::String,
          B::StridedArray, sftB::Int64, idxB::String,
          C::StridedArray, sftC::Int64, idxC::String,
          α::Number, β::Number) = begin
    # convert stride unit in top duals.
    stA::Array{Int64} = topst .* [strides(A)...]
    stB::Array{Int64} = topst .* [strides(B)...]
    stC::Array{Int64} = topst .* [strides(C)...]
    # explicitly specify tensor dimensions.
    szA::Array{Int64} = [size(A)...]
    szB::Array{Int64} = [size(B)...]
    szC::Array{Int64} = [size(C)...]
    #=println(szA, stA, sftA, idxA, typeof(A))
      println(szC, stC, sftC, idxC, typeof(C)) 
      =#
    # call wrapper function tblis_contract_?.
    ccall(contract_lazy, Cvoid,
          (Ptr{Cvoid}, Int64, Ptr{Int64}, Ptr{Int64}, Int64, Ptr{UInt8},
           Ptr{Cvoid}, Int64, Ptr{Int64}, Ptr{Int64}, Int64, Ptr{UInt8},
           Ptr{Cvoid}, Int64, Ptr{Int64}, Ptr{Int64}, Int64, Ptr{UInt8},
           Ptr{Cvoid}, Ptr{Cvoid}),
          A, length(size(A)), szA, stA, sftA, idxA,
          B, length(size(B)), szB, stB, sftB, idxB,
          C, length(size(C)), szC, stC, sftC, idxC, [α], [β])
    return nothing
end


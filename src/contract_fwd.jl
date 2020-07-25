# tovalue unveils base type of duals.
tovalue(::Type{<:Dual{Tg, T}}) where {Tg, T} = tovalue(T)
tovalue(T::Type{<:Union{Float32, Float64}}) = T


contract(A::Array{T}, B::Array{T}, idxA::String, idxB::String, idxC::String) where {T} = begin
    contract(A, idxA, B, idxB, idxC)
end

contract(A::Array{T}, idxA::String, B::Array{T}, idxB::String, idxC::String) where {T} = begin
    # (unsafe) dimension lookup for A & B indices.
    dimsA = Dict([(c, size(A)[i]) for (i, c)=enumerate(split(idxA, ""))])
    dimsB = Dict([(c, size(B)[i]) for (i, c)=enumerate(split(idxB, ""))])
    merge!(dimsA, dimsB)
    # calculate final size of tensor C and allocate.
    szC = ([dimsA[c] for c=split(idxC, "")]..., )
    C = zeros(T, szC...)
    # invoke the dispatch process.
    contract!(A, idxA, B, idxB, C, idxC)
    # return result in allocated container.
    return C
end

"Entry of contraction. Here idx{A,B,C} are 3 entries corresponding to e.g. \"ik,jk->ij\"."
contract!(A::Array{T}, idxA::String,
          B::Array{T}, idxB::String,
          C::Array{T}, idxC::String) where {T} = begin
    contract!(T, sizeof(T)÷sizeof(tovalue(T)),
              A, 0, idxA, B, 0, idxB, C, 0, idxC)
end

"Dispatcher for Dual types of ForwardDiff.jl."
contract!(::Type{<:Dual{Tg, T, ND}}, topst::Int64, # top-level stride
          A::Array, sftA::Int64, idxA::String, # arrays here are all at their top-level (not dispatched)
          B::Array, sftB::Int64, idxB::String,
          C::Array, sftC::Int64, idxC::String) where {Tg, T, ND} = begin
    # direct dispatch for value types.
    contract!(T, topst, A, sftA, idxA, B, sftB, idxB, C, sftC, idxC)

    # for all differentials
    # TODO: consider exchangability
    for id = 1:ND
        # unpacks one layer of dual. note that differentials are also in value's type.
        contract!(T, topst,
                  A, sftA + id*sizeof(T), idxA,
                  B, sftB,                idxB,
                  C, sftC + id*sizeof(T), idxC)
        contract!(T, topst,
                  A, sftA,                idxA,
                  B, sftB + id*sizeof(T), idxB,
                  C, sftC + id*sizeof(T), idxC)
    end
end

# These are final dispatchers for plain numbers.
# As ForwardDiff.jl only gives support for real numbers, only s/d are instantiated.

contract!(::Type{<:Float32}, topst::Int64,
          A::Array, sftA::Int64, idxA::String,
          B::Array, sftB::Int64, idxB::String,
          C::Array, sftC::Int64, idxC::String) = begin
    contract!(dlsym(dll_obj, :tblis_contract_s), topst,
              A, sftA, idxA,
              B, sftB, idxB,
              C, sftC, idxC);
end

contract!(::Type{<:Float64}, topst::Int64,
          A::Array, sftA::Int64, idxA::String,
          B::Array, sftB::Int64, idxB::String,
          C::Array, sftC::Int64, idxC::String) = begin
    contract!(dlsym(dll_obj, :tblis_contract_d), topst,
              A, sftA, idxA,
              B, sftB, idxB,
              C, sftC, idxC);
end

contract!(contract_lazy::Ptr, topst::Int64,
          A::Array, sftA::Int64, idxA::String,
          B::Array, sftB::Int64, idxB::String,
          C::Array, sftC::Int64, idxC::String) = begin
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
           Ptr{Cvoid}, Int64, Ptr{Int64}, Ptr{Int64}, Int64, Ptr{UInt8}),
          A, length(size(A)), szA, stA, sftA, idxA,
          B, length(size(B)), szB, stB, sftB, idxB,
          C, length(size(C)), szC, stC, sftC, idxC)
    return nothing
end


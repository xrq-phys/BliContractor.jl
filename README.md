# BliContractor.jl

> Fast tensor contractor for Julia, based on TBLIS, with high-order AD and Stride support, within 400* lines. <br />
> \* Result may vary as more dispatch rules are added.

- All these are made possible thanks to [TBLIS](https://github.com/devinamatthews/tblis);

## Installation

```
] add BliContractor
```
This will link the Julia package against TBLIS library vendored by `tblis_jll`.

If one wants to use their own TBLIS build, specify their TBLIS installation root
 with `export TBLISDIR=${PathToYourTBLIS}`, start Julia and run:
```
] build BliContractor
```
BliContractor.jl will be relinked to use the user-defined TBLIS installation.
Build steps as well as environment specification needs to be done *only once*.

## Usage

### From TensorOperations.jl

My implementation now contains necessary overriding of [TensorOperation.jl](https://github.com/Jutho/TensorOperations.jl)'s CPU backend method. One can directly invoke the `@tensor` macro (or the `ncon` function, etc.) and reach TBLIS backend.

```julia
using TensorOperations
using BliContractor

A = rand(10, 10, 10, 10);
B = rand(10, 10, 10, 10);
C = ones(10, 10, 10, 10);
@tensor C[i, a, k, c] = A[i, j, k, l] * B[a, l, c, j]
```

Supported datatypes are `Float32, Float64, ComplexF32, ComplexF64, Dual{N, Float32}` and `Dual{N, Float64}`. See also below for AD support.

### As Standalone Package

The simplest API is given by `contract`:
```julia
using BliContractor
using ForwardDiff: Dual
At = rand( 6, 4, 5) * Dual(1.0, 1.0);
Bt = rand(10, 5, 4) * Dual(1.0, 0.0);
contract(At, "ikl", Bt, "jlk", "ij")
# or equivalently:
contract(At, Bt, "ikl", "jlk", "ij")
```
Index notation here is the same as TBLIS, namely the Einstein's summation rules. This `contract` (with exclamation mark `!`) is also the only subroutine with [Zygote](https://github.com/FluxML/Zygote.jl)'s backward derivative support (while all subroutines in this module supports [ForwardDiff](https://github.com/JuliaDiff/ForwardDiff.jl)'s forward differential).

If one's having destination tensor `C` preallocated, a `contract!` routine (which is
 in fact called by `contract`) is also available:

```julia
Ct = zeros(6, 10) * Dual(1.0, 0.0);
contract!(At, "ikl", Bt, "jlk", Ct, "ij")
```

Tensors can be `Array`s or strided `SubArray`s:
```julia
Aw = view(At, :, 1:2:4, :);
# Unlike the case of BLAS,
# first dimension is not required to be 1 for performance to be nice:
Bw = view(Bt, 1:2:10, :, 1:2:4);
Cv = zeros(6, 5) * Dual(1.0, 0.0);
contract!(Aw, "ikl", Bw, "jlk", Cv, "ij")
```

## Roadmap

- [ ] Explicitly dispatch mixed multiplication of plain values with Duals, e.g. `(Float64, Dual{Tag, Float64})` or `(Dual{Tag, Float64}, Dual{Tag, Dual{Tag, Float64}})`, though they are already available via type conversion;
- [x] Let it play well with [Zygote.jl](https://github.com/FluxML/Zygote.jl), to at least 1st order;
- [x] Enable 2nd order pullback for Zygote.jl.

## On 2nd Derivative with Zygote.jl
Second derivative through `hessian` is already working on Zygote.jl's `master` branch, but taking `pullback` 2 times requires something more which is currently only available in the upstream development branch:
[**DhairyaLGandhi/Zygote.jl**/`dg/iddict`](https://github.com/DhairyaLGandhi/Zygote.jl/tree/dg/iddict).

## Performance

Here is a brief benchmark report given by [BenchmarkTools](https://github.com/JuliaCI/BenchmarkTools.jl). System spec. are the following:

- OS: macOS 10.15.7
- Processor: Intel(R) Core(R) i5 8259U
- Frequency: 2.30GHz
- OpenMP Thread Used: 4

### GEMM-Incompatible Contractions

A contraction which can not be handled by BLAS' GEMM routines is tested to show superiority of TBLIS over blocked-GEMM calls launched by TensorOperations.jl.

```
julia> @benchmark begin
           @tensor C[i, a] = A[i, j, k, l] * B[a, k, l, j]
           C
       end setup=(A=rand(40,40,40,40);B=rand(40,40,40,40);C=zeros(40,40))
BenchmarkTools.Trial: 
  memory estimate:  2.03 KiB
  allocs estimate:  33
  --------------
  minimum time:     8.118 ms (0.00% GC)
  median time:      8.243 ms (0.00% GC)
  mean time:        8.290 ms (0.00% GC)
  maximum time:     10.373 ms (0.00% GC)
  --------------
  samples:          260
  evals/sample:     1
  
julia> using BliContractor # Import BliContractor s.t. @tensor is overriden
  
julia> @benchmark begin
           @tensor C[i, a] = A[i, j, k, l] * B[a, k, l, j]
           C
       end setup=(A=rand(40,40,40,40);B=rand(40,40,40,40);C=zeros(40,40))
BenchmarkTools.Trial: 
  memory estimate:  5.36 KiB
  allocs estimate:  96
  --------------
  minimum time:     5.444 ms (0.00% GC)
  median time:      6.110 ms (0.00% GC)
  mean time:        6.283 ms (0.00% GC)
  maximum time:     9.298 ms (0.00% GC)
  --------------
  samples:          304
  evals/sample:     1
```
Note that this contraction order is a quite extreme one. Usually TBLIS and TensorOperations.jl has quite close GFlOps performance.

### Generic Strided Tensors

Generic-strided tensors test shows that TBLIS' giving better performance over other implementations when one has a non-unit column stride (as is the case of `ForwardDiff.Dual`).

For plain `Float64` number:
```
julia> @benchmark ein"ikl,jlk->ij"(At, Bt) setup=(At=rand(300,400,500);Bt=rand(80,500,400);)
BenchmarkTools.Trial: 
  memory estimate:  122.26 MiB
  allocs estimate:  37
  --------------
  minimum time:     113.659 ms (0.00% GC)
  median time:      116.639 ms (0.00% GC)
  mean time:        117.971 ms (0.00% GC)
  maximum time:     131.518 ms (0.00% GC)
  --------------
  samples:          13
  evals/sample:     1

julia> @benchmark contract(At, Bt, "ikl", "jlk", "ij") setup=(At=rand(300,400,500);Bt=rand(80,500,400);)
BenchmarkTools.Trial: 
  memory estimate:  192.42 KiB #< Not that credible as external C is called.
  allocs estimate:  74
  --------------
  minimum time:     104.077 ms (0.00% GC)
  median time:      110.575 ms (0.00% GC)
  mean time:        111.040 ms (0.00% GC)
  maximum time:     117.738 ms (0.00% GC)
  --------------
  samples:          13
  evals/sample:     1
```

For `Dual{Tag, Float64, 1}`:
```
julia> @benchmark begin
           @tensor C[i, j] := At[i, k, l] * Bt[j, l, k]
           C
       end setup=(At=rand(300,400,500)*Dual{Nothing}(1.0,0.4);Bt=rand(80,500,400)*Dual{Nothing}(1.0,0.4);)
BenchmarkTools.Trial: 
  memory estimate:  376.22 KiB
  allocs estimate:  21
  --------------
  minimum time:     4.936 s (0.00% GC)
  median time:      4.936 s (0.00% GC)
  mean time:        4.936 s (0.00% GC)
  maximum time:     4.936 s (0.00% GC)
  --------------
  samples:          1
  evals/sample:     1

julia> @benchmark begin
           contract(At, Bt, "ikl", "jlk", "ij");
       end setup=(At=rand(300,400,500)*Dual{Nothing}(1.0,0.4);Bt=rand(80,500,400)*Dual{Nothing}(1.0,0.4);)
BenchmarkTools.Trial: 
  memory estimate:  381.84 KiB
  allocs estimate:  95
  --------------
  minimum time:     421.861 ms (0.00% GC)
  median time:      469.152 ms (0.00% GC)
  mean time:        481.471 ms (0.00% GC)
  maximum time:     565.719 ms (0.00% GC)
  --------------
  samples:          4
  evals/sample:     1
```

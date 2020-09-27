# BliContractor.jl

> Fast tensor contractor for Julia, based on TBLIS, with AD support, within 300* lines. <br />
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

The simplest API is given by `contract`:
```julia
using BliContractor
using ForwardDiff: Dual
At = rand( 3, 4, 5) * Dual{Nothing}(1.0, 1.0);
Bt = rand(10, 5, 4) * Dual{Nothing}(1.0, 0.0);
contract(At, Bt, "ikl", "jlk", "ij")
```

For advanced usage, one might refer to the docstrings.

## Roadmap

- [ ] Explicitly dispatch mixed multiplication of plain values with Duals, e.g. `(Float64, Dual{Tag, Float64})` or `(Dual{Tag, Float64}, Dual{Tag, Dual{Tag, Float64}})`, though they are already available via type conversion;
- [x] Let it play well with [Zygote.jl](https://github.com/FluxML/Zygote.jl), to at least 1st order;
- [x] Enable 2nd order pullback for Zygote.jl.

## On 2nd Derivative with Zygote.jl
Second derivative through `hessian` is already working on Zygote.jl's `master` branch, but taking `pullback` 2 times requires something more which is currently only available in the upstream development branch:
[**DhairyaLGandhi/Zygote.jl**/`dg/iddict`](https://github.com/DhairyaLGandhi/Zygote.jl/tree/dg/iddict).

## Performance

Here is a brief benchmark report given by [BenchmarkTools](https://github.com/JuliaCI/BenchmarkTools.jl).

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

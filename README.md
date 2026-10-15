# Pumpkin.jl

[Pumpkin.jl](https://github.com/blegat/Pumpkin.jl) is a wrapper for
[Pumpkin](https://github.com/ConSol-Lab/Pumpkin), a lazy clause generation
constraint programming solver developed at the ConSol Lab of TU Delft.

## Affiliation

This wrapper is maintained by NexOR Optimization and is not officially part of the
Pumpkin project.

## License

`Pumpkin.jl` is licensed under the [MIT License](LICENSE.md).

The underlying solver, [ConSol-Lab/Pumpkin](https://github.com/ConSol-Lab/Pumpkin),
is licensed under the [MIT or Apache 2.0 license](https://github.com/ConSol-Lab/Pumpkin#license).

## Install

Install Pumpkin.jl using the Julia package manager:

```julia
import Pkg
Pkg.add("Pumpkin")
```

This also installs the `pumpkin-solver` executable via
[Pumpkin_jll.jl](https://github.com/JuliaBinaryWrappers/Pumpkin_jll.jl) and
`libminizinc` via [MiniZinc.jl](https://github.com/jump-dev/MiniZinc.jl).

## Use with JuMP

Pumpkin has no floating point variables, so the model must be built over
`Int`: use `GenericModel{Int}` rather than the `Float64` default of `Model`.

```julia
using JuMP
import Pumpkin

model = GenericModel{Int}(Pumpkin.Optimizer)
@variable(model, 1 <= x[1:3] <= 3, Int)
@constraint(model, x in MOI.AllDifferent(3))
@objective(model, Max, sum(i * x[i] for i in 1:3))
optimize!(model)
value.(x)  # [1, 2, 3]
```

With plain MathOptInterface:

```julia
import MathOptInterface as MOI
import Pumpkin

<<<<<<< HEAD
model = MOI.instantiate(Pumpkin.Optimizer)
=======
model = MOI.Utilities.CachingOptimizer(
    Pumpkin.Model{Int}(),
    Pumpkin.Optimizer(),
)
>>>>>>> 94eb2a8 (Initial commit)
```

## How it works

`Pumpkin.Optimizer` is a [MiniZinc.jl](https://github.com/jump-dev/MiniZinc.jl)
optimizer configured with the solver configuration (`.msc`) that
`Pumpkin_jll` ships. MiniZinc compiles the model to FlatZinc using Pumpkin's
own library of redefinitions, then hands it to `pumpkin-solver`.

Going through MiniZinc means the supported constraints are those of
MiniZinc.jl, not only the handful of predicates Pumpkin implements natively:
globals such as `MOI.Circuit` that have no Pumpkin propagator are decomposed
by the MiniZinc standard library into ones that do. See the
[MiniZinc.jl README](https://github.com/jump-dev/MiniZinc.jl#mathoptinterface-api)
for the list of supported constraints and attributes.

## Proof logging

Pumpkin can emit a machine-checkable certificate of infeasibility or
optimality in the DRCP format, verifiable independently of the solver with
[fzn-drcp-check](https://github.com/ConSol-Lab/fzn-drcp-check).

Proofs require every inference to be explainable, so they use a different
FlatZinc library, which decomposes every global constraint but `cumulative`
into linear constraints. Select that configuration with:

```julia
Pumpkin.Optimizer(; proof = true)
```

This trades propagation strength for provability, so it is slower on models
that would otherwise use the global propagators.

Note that this only selects the library. Writing the certificate itself needs
`--proof-path`, and MiniZinc.jl forwards no solver flags beyond
`--time-limit` and `--num-solutions`, so the file cannot yet be requested
from Julia. Until that changes, write the model out and call the solver
yourself:

```julia
set_attribute(model, "model_filename", "model.mzn")
optimize!(model)

using MiniZinc_jll, Pumpkin
run(`$(MiniZinc_jll.minizinc()) --solver $(Pumpkin.solver_configuration(; proof = true))
     --proof-path model.drcp model.mzn`)
```

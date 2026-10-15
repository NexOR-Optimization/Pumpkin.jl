module Pumpkin

import MathOptInterface as MOI
import MiniZinc
import Pumpkin_jll

"""
    solver_configuration(; proof::Bool = false)

The path to the MiniZinc solver configuration (`.msc`) of Pumpkin, as shipped
by `Pumpkin_jll`.

With `proof = false`, the configuration uses Pumpkin's native global
constraint propagators. With `proof = true`, it uses the library that
decomposes every global constraint but `cumulative` into linear constraints,
which is what Pumpkin needs in order to log a DRCP proof.
"""
function solver_configuration(; proof::Bool = false)
    name = proof ? "pumpkin-proof.msc" : "pumpkin.msc"
    path =
        joinpath(Pumpkin_jll.artifact_dir, "share", "minizinc", "solvers", name)
    if !isfile(path)
        error(
            "The installed `Pumpkin_jll` does not ship `$(name)`. The " *
            "MiniZinc solver configurations were added in `Pumpkin_jll` " *
            "v0.5.0+1; run `import Pkg; Pkg.update(\"Pumpkin_jll\")`.",
        )
    end
    return path
end

"""
    Optimizer(::Type{T} = Int; proof::Bool = false) where {T}

Create a new optimizer that solves with Pumpkin through MiniZinc.

`T` is the coefficient type of the model, matching `MiniZinc.Optimizer{T}`.
It defaults to `Int` because Pumpkin has no floating point variables: with
`T = Float64`, MiniZinc.jl writes coefficients such as `1.0*x`, which makes
MiniZinc flatten the model over `var float` and Pumpkin reject it. Use a
`JuMP.GenericModel{Int}` rather than the `Float64` default of `JuMP.Model`.

`proof` selects the solver configuration, see [`solver_configuration`](@ref).

## Example

```julia
using JuMP
import Pumpkin

model = GenericModel{Int}(Pumpkin.Optimizer)
@variable(model, 1 <= x[1:3] <= 3, Int)
@constraint(model, x in MOI.AllDifferent(3))
@objective(model, Max, sum(i * x[i] for i in 1:3))
optimize!(model)
```
"""
function Optimizer(::Type{T} = Int; proof::Bool = false) where {T}
    return MiniZinc.Optimizer{T}(solver_configuration(; proof = proof))
end

"""
    Model{T}() where {T}

The in-memory model that [`Optimizer`](@ref) consumes, re-exported from
MiniZinc.jl so that the `MOI.Utilities.CachingOptimizer` idiom does not need
MiniZinc.jl to be imported as well.
"""
const Model = MiniZinc.Model

end # module Pumpkin

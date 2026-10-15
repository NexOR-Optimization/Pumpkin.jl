module TestMOIWrapper

using Test
import MathOptInterface as MOI
import Pumpkin

function runtests()
    for name in names(@__MODULE__; all = true)
        if startswith("$(name)", "test_")
            @testset "$(name)" begin
                getfield(@__MODULE__, name)()
            end
        end
    end
    return
end

"""
    test_runtests()

Run the constraint programming part of `MOI.Test`. This is the same scope
MiniZinc.jl tests its own optimizer with: the rest of the suite covers
continuous and conic problems that neither MiniZinc.jl nor Pumpkin model.
"""
function test_runtests()
    model = MOI.Utilities.CachingOptimizer(
        Pumpkin.Model{Int}(),
        Pumpkin.Optimizer(),
    )
    config = MOI.Test.Config(
        Int;
        exclude = Any[
            # Pumpkin is a constraint programming solver: it has no notion of
            # a dual solution, a basis or a bound on the objective.
            MOI.ConstraintBasisStatus,
            MOI.VariableBasisStatus,
            MOI.ConstraintDual,
            MOI.DualObjectiveValue,
            MOI.DualStatus,
            MOI.ObjectiveBound,
            MOI.SolverVersion,
        ],
    )
    MOI.Test.runtests(model, config; include = String["test_cpsat_"])
    return
end

function test_SolverName()
    @test MOI.get(Pumpkin.Optimizer(), MOI.SolverName()) == "MiniZinc"
    return
end

function test_solver_configuration()
    @test isfile(Pumpkin.solver_configuration())
    @test isfile(Pumpkin.solver_configuration(; proof = true))
    @test Pumpkin.solver_configuration() !=
          Pumpkin.solver_configuration(; proof = true)
    return
end

function _all_different_model(optimizer)
    model = MOI.Utilities.CachingOptimizer(Pumpkin.Model{Int}(), optimizer)
    x = MOI.add_variables(model, 3)
    MOI.add_constraint.(model, x, MOI.Integer())
    MOI.add_constraint.(model, x, MOI.Interval(1, 3))
    MOI.add_constraint(model, MOI.VectorOfVariables(x), MOI.AllDifferent(3))
    f = 1 * x[1] + 2 * x[2] + 3 * x[3]
    MOI.set(model, MOI.ObjectiveSense(), MOI.MAX_SENSE)
    MOI.set(model, MOI.ObjectiveFunction{typeof(f)}(), f)
    MOI.optimize!(model)
    return model, x
end

function test_all_different()
    model, x = _all_different_model(Pumpkin.Optimizer())
    @test MOI.get(model, MOI.TerminationStatus()) == MOI.OPTIMAL
    @test MOI.get(model, MOI.PrimalStatus()) == MOI.FEASIBLE_POINT
    @test MOI.get(model, MOI.VariablePrimal(), x) == [1, 2, 3]
    @test MOI.get(model, MOI.ObjectiveValue()) == 14
    return
end

"""
    test_proof_configuration()

The proof configuration decomposes the global constraints into linear ones,
so it must reach the same optimum by a different route.
"""
function test_proof_configuration()
    model, x = _all_different_model(Pumpkin.Optimizer(; proof = true))
    @test MOI.get(model, MOI.TerminationStatus()) == MOI.OPTIMAL
    @test MOI.get(model, MOI.VariablePrimal(), x) == [1, 2, 3]
    return
end

"""
    test_circuit()

`circuit` has no Pumpkin propagator; MiniZinc decomposes it into the
predicates Pumpkin does implement. This is what the wrapper gains by going
through MiniZinc rather than writing FlatZinc directly.
"""
function test_circuit()
    model = MOI.Utilities.CachingOptimizer(
        Pumpkin.Model{Int}(),
        Pumpkin.Optimizer(),
    )
    x = MOI.add_variables(model, 4)
    MOI.add_constraint.(model, x, MOI.Integer())
    MOI.add_constraint.(model, x, MOI.Interval(1, 4))
    MOI.add_constraint(model, MOI.VectorOfVariables(x), MOI.Circuit(4))
    MOI.optimize!(model)
    @test MOI.get(model, MOI.TerminationStatus()) == MOI.OPTIMAL
    # A circuit visits every node exactly once.
    @test sort(MOI.get(model, MOI.VariablePrimal(), x)) == 1:4
    return
end

function test_infeasible()
    model = MOI.Utilities.CachingOptimizer(
        Pumpkin.Model{Int}(),
        Pumpkin.Optimizer(),
    )
    x, _ = MOI.add_constrained_variable(model, MOI.Interval(1, 2))
    MOI.add_constraint(model, x, MOI.Integer())
    MOI.add_constraint(model, 1 * x, MOI.LessThan(0))
    MOI.optimize!(model)
    @test MOI.get(model, MOI.TerminationStatus()) == MOI.INFEASIBLE
    @test MOI.get(model, MOI.ResultCount()) == 0
    return
end

end  # module

TestMOIWrapper.runtests()

module TestJuMP

using Test
using JuMP
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
    _model()

Pumpkin has no floating point variables, so the JuMP model must be built over
`Int` rather than the `Float64` default of `JuMP.Model`.
"""
function _model()
    model = GenericModel{Int}(Pumpkin.Optimizer)
    set_silent(model)
    return model
end

function test_all_different()
    model = _model()
    @variable(model, 1 <= x[1:3] <= 3, Int)
    @constraint(model, x in MOI.AllDifferent(3))
    @objective(model, Max, sum(i * x[i] for i in 1:3))
    optimize!(model)
    @test is_solved_and_feasible(model)
    @test value.(x) == [1, 2, 3]
    @test objective_value(model) == 14
    return
end

"""
    test_sudoku()

Solve a 4x4 Sudoku with the `all_different` propagator, once per row, column
and 2x2 block.
"""
function test_sudoku()
    given = [
        1 0 0 0
        0 0 3 0
        0 4 0 0
        0 0 0 2
    ]
    model = _model()
    @variable(model, 1 <= x[1:4, 1:4] <= 4, Int)
    for i in 1:4, j in 1:4
        if given[i, j] != 0
            fix(x[i, j], given[i, j]; force = true)
        end
    end
    for i in 1:4
        @constraint(model, x[i, :] in MOI.AllDifferent(4))
        @constraint(model, x[:, i] in MOI.AllDifferent(4))
    end
    for i in (1, 3), j in (1, 3)
        @constraint(model, vec(x[i:(i+1), j:(j+1)]) in MOI.AllDifferent(4))
    end
    optimize!(model)
    @test is_solved_and_feasible(model)
    solution = value.(x)
    for i in 1:4
        @test sort(solution[i, :]) == 1:4
        @test sort(solution[:, i]) == 1:4
    end
    for i in (1, 3), j in (1, 3)
        @test sort(vec(solution[i:(i+1), j:(j+1)])) == 1:4
    end
    return
end

"""
    test_scheduling()

Minimise the makespan of five unit-resource tasks that all share a machine of
capacity one, which Pumpkin propagates with `cumulative`.
"""
function test_scheduling()
    durations = [3, 2, 4, 1, 2]
    n = length(durations)
    horizon = sum(durations)
    model = _model()
    @variable(model, 0 <= start[1:n] <= horizon, Int)
    @variable(model, duration[i in 1:n] == durations[i], Int)
    @variable(model, resource[1:n] == 1, Int)
    @variable(model, capacity == 1, Int)
    @constraint(
        model,
        [start; duration; resource; capacity] in MOI.Cumulative(3n + 1),
    )
    @variable(model, 0 <= makespan <= horizon, Int)
    @constraint(model, [i in 1:n], makespan >= start[i] + durations[i])
    @objective(model, Min, makespan)
    optimize!(model)
    @test is_solved_and_feasible(model)
    # The tasks are serialised on a single machine, so the makespan is the sum
    # of the durations.
    @test objective_value(model) == horizon
    return
end

"""
    test_travelling_salesperson()

A 4-city TSP over the `circuit` global, which MiniZinc decomposes for
Pumpkin.
"""
function test_travelling_salesperson()
    distance = [
        0 1 9 9
        1 0 1 9
        9 1 0 1
        9 9 1 0
    ]
    model = _model()
    @variable(model, 1 <= next[1:4] <= 4, Int)
    @constraint(model, next in MOI.Circuit(4))
    @variable(model, 0 <= step[1:4] <= 9, Int)
    for i in 1:4
        @constraint(
            model,
            [step[i]; next[i]] in
            MOI.Table(hcat([distance[i, j] for j in 1:4], collect(1:4)))
        )
    end
    @objective(model, Min, sum(step))
    optimize!(model)
    @test is_solved_and_feasible(model)
    # The cycle 1 -> 2 -> 3 -> 4 -> 1 costs 1 + 1 + 1 + 9.
    @test objective_value(model) == 12
    return
end

end  # module

TestJuMP.runtests()

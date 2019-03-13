#  Copyright 2017-19, Oscar Dowson.
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at http://mozilla.org/MPL/2.0/.

using SDDP, Test, GLPK

@testset "Forward Pass" begin
    model = SDDP.PolicyGraph(SDDP.LinearGraph(2);
                sense = :Max,
                bellman_function = SDDP.AverageCut(upper_bound = 100.0),
                optimizer = with_optimizer(GLPK.Optimizer)
                    ) do node, stage
        @variable(node, x, SDDP.State, initial_value = 0.0)
        @stageobjective(node, x.out)
        SDDP.parameterize(node, stage * [1, 3], [0.5, 0.5]) do ω
            JuMP.set_upper_bound(x.out, ω)
        end
    end
    scenario_path, sampled_states, objective_states, cumulative_value =
        SDDP.forward_pass(
            model,
            SDDP.Options(
                model,
                Dict(:x => 1.0),
                SDDP.InSampleMonteCarlo(),
                SDDP.Expectation(),
                0.0,
                true
            )
        )
    simulated_value = 0.0
    for ((node_index, noise), state) in zip(scenario_path, sampled_states)
        @test state[:x] == noise
        simulated_value += noise
    end
    @test simulated_value == cumulative_value
end

@testset "solve" begin
    model = SDDP.PolicyGraph(SDDP.LinearGraph(2),
                bellman_function = SDDP.AverageCut(lower_bound = 0.0),
                optimizer = with_optimizer(GLPK.Optimizer)
                    ) do node, stage
        @variable(node, x >= 0, SDDP.State, initial_value = 0.0)
        @stageobjective(node, x.out)
        SDDP.parameterize(node, stage * [1, 3], [0.5, 0.5]) do ω
            JuMP.set_lower_bound(x.out, ω)
        end
    end
    SDDP.train(model; iteration_limit = 4)
    @test SDDP.termination_status(model) == :iteration_limit
end

function MOI.get(::GLPK.Optimizer, ::MOI.ListOfVariableAttributesSet)
    return MOI.AbstractVariableAttribute[MOI.VariableName()]
end
function MOI.get(::GLPK.Optimizer, ::MOI.ListOfConstraintAttributesSet)
    return MOI.AbstractConstraintAttribute[MOI.ConstraintName()]
end

@testset "infeasible model" begin
    model = SDDP.LinearPolicyGraph(
                stages = 2,
                lower_bound = 0.0,
                optimizer = with_optimizer(GLPK.Optimizer)
                    ) do node, stage
        @variable(node, x >= 0, SDDP.State, initial_value = 0.0)
        @constraint(node, x.out <= -1)
        @stageobjective(node, x.out)
    end
    @test_throws Exception SDDP.train(model; iteration_limit = 1)
    @test isfile("subproblem.mps")
    rm("subproblem.mps")
    @test isfile("subproblem.lp")
    rm("subproblem.lp")
end

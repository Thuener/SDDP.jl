#  Copyright 2018, Oscar Dowson
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at http://mozilla.org/MPL/2.0/.

#==
    This example comes from
        https://github.com/blegat/StochasticDualDynamicProgramming.jl/blob/fe5ef82db6befd7c8f11c023a639098ecb85737d/test/prob5.2_2stages.jl
==#

using Kokako, GLPK, Test

function test_prob52_2stages()
    model = Kokako.PolicyGraph(Kokako.LinearGraph(2),
                bellman_function = Kokako.AverageCut(lower_bound=0.0),
                optimizer = with_optimizer(GLPK.Optimizer)
                ) do subproblem, stage
        # ========== Problem data ==========
        n = 4
        m = 3
        ic = [16, 5, 32, 2]
        C = [25, 80, 6.5, 160]
        T = [8760, 7000, 1500] / 8760
        D2 = [diff([0, 3919, 7329, 10315])  diff([0, 7086, 9004, 11169])]
        p2 = [0.9, 0.1]
        # ========== State Variables ==========
        # @state(subproblem, x′[i=1:n] >= 0, x == 0.0)
        @variable(subproblem, x[i=1:n])
        @variable(subproblem, x′[i=1:n] >= 0)
        Kokako.add_state_variable.(subproblem, x, x′, 0.0)
        # ========== Variables ==========
        @variables(subproblem, begin
            y[1:n, 1:m] >= 0
            v[1:n] >= 0
            penalty >= 0
            rhs_noise[1:m]  # Dummy variable for RHS noise term.
        end)
        # ========== Constraints ==========
        @constraints(subproblem, begin
            x′ .== x + v
            [i=1:n], sum(y[i, :]) <= x[i]
            [j=1:m], sum(y[:, j]) + penalty >= rhs_noise[j]
        end)
        if stage == 2
            # No investment in last stage.
            @constraint(subproblem, sum(v) == 0)
        end
        # ========== Uncertainty ==========
        if stage != 1 # no uncertainty in first stage
            Kokako.parameterize(subproblem, 1:size(D2, 2), p2) do ω
                for j in 1:m
                    JuMP.fix(rhs_noise[j], D2[j, ω])
                end
            end
        end
        # ========== Stage objective ==========
        @stageobjective(subproblem, Min,
            ic' * v +  C' * y * T + 1e6 * penalty)
        return
    end

    status = Kokako.train(model, iteration_limit = 50)
    @test Kokako.calculate_bound(model) ≈ 340315.52 atol=0.1
    # sim = simulate(mod, 1, [:x, :penalty])
    # @test length(sim) == 1
    # @test isapprox(sim[1][:x][1], [5085,1311,3919,854])
end

test_prob52_2stages()

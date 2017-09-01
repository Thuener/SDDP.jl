# Simplified Hydrothermal Dispatch
# $FCF(v_{t-1}) =$
# \begin{array}{r l}
# \min\limits_{g,s,u,s \geq 0} & 100 g_{1,t} + 1000 g_{2,t}\\
# s.t. & g_{1,t} + g_{2,t} + u_t  = 150 \\
# & v_t + u_t + s_t = v_{t-1} + a_t \\
# & 0 \leq v_t \leq 200 \\
# & 0 \leq u_t \leq 150 \\
# & 0 \leq g_{1,t} \leq 50 \\
# & 0 \leq g_{2,t} \leq 50 \\
# \end{array}

# load some packages
using SDDP, JuMP, Clp, Base.Test

# Initialise SDDP Model
m = SDDPModel(
                  sense = :Min,          
                 stages = 3,
                 solver = ClpSolver(), 
        objective_bound = 0             
                                        ) do sp, t
    
    # ------------------------------------------------------------------
    #   SDDP State Variables
    # Level of upper reservoir
    @state(sp,    0 <= v <= 200, v0 == 50)
    
    # ------------------------------------------------------------------
    #   Additional variables
    # Variables
    # g  - thermoelectric generation
    # u  - turbine
    # v  - reservoir volume
    # a  - affluence
    # s  - spillway
    @variable(sp, 0 <= g[1:2] <= 100)
    @variable(sp, 0 <= u <= 150)
    @variable(sp, s >= 0 )
    
    # ------------------------------------------------------------------
    #   Constraints
    # Demand
    @constraint(sp, g[1] + g[2] + u == 150)
    
    # ------------------------------------------------------------------
    #   Noise
    # rainfall noises
    @noise(sp, a = linspace(50, 0, 10), v + u + s == v0 + a) 
    
    # Objective function 
    stageobjective!(sp, 100*g[1] + 1000*g[2] ) 
end

# For repeatability
srand(11111)

solvestatus = solve(m,
    max_iterations = 20,
    time_limit     = 600, 
    simulation     = MonteCarloSimulation(
                        frequency = 5,
                        min       = 10,
                        step      = 10,
                        max       = 100,
                        termination = false
                    ),
     #print_level=0
)

@test solvestatus == :converged 
@test isapprox(getbound(m), 7500, atol=1e-2)
function save(filepath::String, m::SDDPModel)
    mkdir(filepath)
    # save mps files for subproblemss
    for (t, stage) in enumerate(SDDP.stages(m))
        for (i, sp) in enumerate(SDDP.subproblems(stage))
            ex = SDDP.ext(sp)
            if SDDP.hasnoises(sp)
                for s in 1:length(ex.noiseprobability)
                    SDDP.setnoise!(sp, ex.noises[s])
                    JuMP.writeMPS(sp, joinpath(filepath, "stage$(t)_$(i)_$(s).mps"))
                end
            else
                JuMP.writeMPS(sp, joinpath(filepath, "stage$(t)_$(i).mps"))
            end
        end
    end

    # save probability transitions
    open(joinpath(filepath, "probabilities"), "w") do pfile
        for (t, stage) in enumerate(SDDP.stages(m))
            stage.transitionprobabilities

            # for (i, sp) in enumerate(SDDP.subproblems(stage))
                # ex = SDDP.ext(sp)
                # ex.noiseprobability
            # end
        end
    end
end

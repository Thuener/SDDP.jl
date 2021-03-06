#  Copyright 2017, Oscar Dowson
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at http://mozilla.org/MPL/2.0/.
#############################################################################

function setnoise!(sp::JuMP.Model, noise::Noise)
    for (c, v) in zip(noise.constraints, noise.values)
        JuMP.setRHS(c, v)
    end
end

function samplenoise(sp::JuMP.Model)
    noiseidx = sample(ext(sp).noiseprobability)
    return noiseidx, ext(sp).noises[noiseidx]
end

"""
    setnoiseprobability!(sp::JuMP.Model, p::Vector{Float64})
"""
function setnoiseprobability!(sp::JuMP.Model, p::Vector{Float64})
    @assert abs(sum(p) - 1.0) < 1e-4 # check sum to one
    resize!(ext(sp).noiseprobability, length(p))
    ext(sp).noiseprobability .= p
end

"""
    @noise(sp, rhs, constraint)
Add a noise constraint (changes in RHS vector) to the subproblem `sp`.
Arguments:
    sp             the subproblem
    rhs            keyword argument `key=value` where `value` is a one-dimensional array containing the noise realisations
    constraint     any valid JuMP `@constraint` syntax that includes the keyword defined by `rhs`
Usage:
    @noise(sp, i=1:2, x + y <= i )
    @noise(sp, i=1:2, x + y <= 3 * rand(2)[i] )
"""
macro noise(sp, kw, c)
    sp = esc(sp)                                # escape the model
    @assert kw.head == KW_SYM                   # check its a keyword
    noisevalues = esc(kw.args[2])            # get the vector of values
    @assert c.head == :call               # check c is a comparison constraint
    @assert length(c.args) == 3                 # check that it has (LHS, (comparison), RHS)
    @assert c.args[1]  in comparison_symbols # check valid constraint type
    constrexpr = :($(c.args[2]) - $(c.args[3])) # LHS - RHS
    quote
        rhs = Float64[]                         # intialise RHS vector
        for val in $noisevalues    # for each noise
            $(esc(kw.args[1])) = val  # set the noisevalue
            push!(rhs, -$(esc(constrexpr)).constant)
         end
        $(esc(kw.args[1])) = $noisevalues[1] # initialise with first noise
        con = $(Expr(                           # add the constraint
                :macrocall, Symbol("@constraint"),
                sp,                             # the subproblem
                esc(c)                          # the constraint expression
                ))
        registernoiseconstraint!($sp, con, rhs)
        con
    end
end

function registernoiseconstraint!(sp::JuMP.Model, con::LinearConstraint, rhs::Vector{Float64})
    if length(ext(sp).noises) == 0
        for r in rhs
            push!(ext(sp).noises, Noise([con], [r]))
        end
    else
        @assert length(ext(sp).noises) == length(rhs)
        for (i, r) in enumerate(rhs)
            push!(ext(sp).noises[i].constraints, con)
            push!(ext(sp).noises[i].values, r)
        end
    end
end

"""
    @noises(sp, rhs, begin
        constraint
    end)
The plural form of `@noise` similar to the JuMP macro `@constraints`.
Usage:
    @noises(sp, i=1:2, begin
               x + y <= i
               x + y <= 3 * rand(2)[i]
    end)
"""
macro noises(m, kw, blk)
    @assert blk.head == :block || error("Invalid syntax for @noises")
    code = quote end
    for line in blk.args
        if !Base.Meta.isexpr(line, :line)
            if line.head == :call && line.args[1] in comparison_symbols
                push!(code.args,
                    Expr(:macrocall, Symbol("@noise"), esc(m), esc(kw), esc(line))
                )
            else
                error("Unknown arguments in @noises")
            end
        end
    end
    push!(code.args, :(nothing))
    return code
end

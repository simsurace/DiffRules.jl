using DiffRules
using FiniteDifferences
using Test

import SpecialFunctions, NaNMath, LogExpFunctions
import Random
Random.seed!(1)

const finitediff = central_fdm(5, 1)

@testset "DiffRules" begin
@testset "check rules" begin

non_diffeable_arg_functions = [(:Base, :rem2pi, 2), (:Base, :ldexp, 2), (:Base, :ifelse, 3)]

for (M, f, arity) in DiffRules.diffrules(; filter_modules=nothing)
    (M, f, arity) ∈ non_diffeable_arg_functions && continue
    if arity == 1
        @test DiffRules.hasdiffrule(M, f, 1)
        deriv = DiffRules.diffrule(M, f, :goo)
        modifier = if f in (:asec, :acsc, :asecd, :acscd, :acosh)
            1.0
        elseif f === :acoth
            1.1 # values too close to 1 are problematic for finite differencing
        elseif f === :log1mexp
            -1.0
        elseif f === :log2mexp
            -0.5
        elseif f in (:airyaix, :airyaiprimex)
            0.1 # values too close to 0 are problematic for finite differencing
        else
            0.0
        end
        @eval begin
            let
                goo = rand() + $modifier
                @test $deriv ≈ finitediff($M.$f, goo) rtol=1e-9 atol=1e-9
                # test for 2pi functions
                if "mod2pi" == string($M.$f)
                    goo = 4pi + $modifier
                    @test NaN === $deriv
                end
            end
        end
    elseif arity == 2
        @test DiffRules.hasdiffrule(M, f, 2)
        derivs = DiffRules.diffrule(M, f, :foo, :bar)
        @eval begin
            let
                if "mod" == string($M.$f)
                    foo, bar = rand() + 13, rand() + 5 # make sure x/y is not integer
                else
                    foo, bar = rand(1:10), rand()
                end
                dx, dy = $(derivs[1]), $(derivs[2])
                if !isnan(dx)
                    @test dx ≈ finitediff(z -> $M.$f(z, bar), float(foo)) rtol=1e-9 atol=1e-9
                end
                if !isnan(dy)
                    @test dy ≈ finitediff(z -> $M.$f(foo, z), bar) rtol=1e-9 atol=1e-9
                end
            end
        end
    elseif arity == 3
        #=
        @test DiffRules.hasdiffrule(M, f, 3)
        derivs = DiffRules.diffrule(M, f, :foo, :bar, :goo)
        @eval begin
            foo, bar, goo = randn(3)
            dx, dy, dz = $(derivs[1]), $(derivs[2]), $(derivs[3])
            if !(isnan(dx))
                @test isapprox(dx, finitediff(x -> $M.$f(x, bar, goo), foo), rtol=0.05)
            end
            if !(isnan(dy))
                @test isapprox(dy, finitediff(y -> $M.$f(foo, y, goo), bar), rtol=0.05)
            end
            if !(isnan(dz))
                @test isapprox(dz, finitediff(z -> $M.$f(foo, bar, z), goo), rtol=0.05)
            end
        end
        =#
    end
end

# Treat rem2pi separately because of its non-numeric second argument:
derivs = DiffRules.diffrule(:Base, :rem2pi, :x, :y)
for xtype in [:Float64, :BigFloat, :Int64]
    for mode in [:RoundUp, :RoundDown, :RoundToZero, :RoundNearest]
        @eval begin
            let
                x = $xtype(rand(1 : 10))
                y = $mode
                dx, dy = $(derivs[1]), $(derivs[2])
                @test dx ≈ finitediff(z -> rem2pi(z, y), float(x)) rtol=1e-9 atol=1e-9
                @test isnan(dy)
            end
        end
    end
end

# Treat ldexp separately because of its integer second argument:
derivs = DiffRules.diffrule(:Base, :ldexp, :x, :y)
for xtype in [:Float64, :BigFloat]
    for ytype in [:Integer, :UInt64, :Int64]
        @eval begin
            let
                x = rand($xtype)
                y = $ytype(rand(1 : 10))
                dx, dy = $(derivs[1]), $(derivs[2])
                @test dx ≈ finitediff(z -> ldexp(z, y), x) rtol=1e-9 atol=1e-9
                @test isnan(dy)
            end
        end
    end
end

# Check negative branch for `airybix` and `airybiprimex`
for f in (:airybix, :airybiprimex)
    deriv = DiffRules.diffrule(:SpecialFunctions, f, :goo)
    @eval begin
        let
            goo = -rand()
            @test $deriv ≈ finitediff(SpecialFunctions.$f, goo) rtol=1e-9 atol=1e-9
        end
    end
end

end

    @testset "diffrules" begin
        rules = @test_deprecated(DiffRules.diffrules())
        @test Set(M for (M, _, _) in rules) == Set((:Base, :SpecialFunctions, :NaNMath))

        rules = DiffRules.diffrules(; filter_modules=nothing)
        @test Set(M for (M, _, _) in rules) == Set((:Base, :SpecialFunctions, :NaNMath, :LogExpFunctions))

        rules = DiffRules.diffrules(; filter_modules=(:Base, :LogExpFunctions))
        @test Set(M for (M, _, _) in rules) == Set((:Base, :LogExpFunctions))
    end
end

# Test ifelse separately as first argument is boolean
#=
@test DiffRules.hasdiffrule(:Base, :ifelse, 3)
derivs = DiffRules.diffrule(:Base, :ifelse, :foo, :bar, :goo)
for cond in [true, false]
    @eval begin
        foo = $cond
        bar, gee = randn(2)
        dx, dy, dz = $(derivs[1]), $(derivs[2]), $(derivs[3])
        @test isapprox(dy, finitediff(y -> ifelse(foo, y, goo), bar), rtol=0.05)
        @test isapprox(dz, finitediff(z -> ifelse(foo, bar, z), goo), rtol=0.05)
    end
end
=#

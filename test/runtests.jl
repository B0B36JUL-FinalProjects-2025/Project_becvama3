using OrbiJul
using Test
using Aqua

@testset "OrbiJul.jl" begin
    @testset "Code quality (Aqua.jl)" begin
        Aqua.test_all(OrbiJul; 
            ambiguities = false,
            unbound_args = false
        )
    end
    @testset "OrbiJul Tests" begin
        include("physics_tests.jl")
        include("serializer_tests.jl")
    end
end


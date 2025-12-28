using OrbiJul
using Test
using Aqua

@testset "OrbiJul.jl" begin
    @testset "Code quality (Aqua.jl)" begin
        Aqua.test_all(OrbiJul)
    end
    # Write your tests here.
end

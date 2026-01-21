using Test
using JSON
using OrbiJul.Serializer
using OrbiJul.Simulator

@testset "Serializer" begin
    original = PhysicsBody(@SVector[1f0, 2f0, 3f0], @SVector[0f0,0,0], 50f0)
    
    # 1. Test Body -> Dict
    d = body_to_dict(original)
    @test d["mass"] == 50.0
    @test d["pos"] == [1.0, 2.0, 3.0]
    
    # 2. Test Dict -> Body (Round trip)
    restored = dict_to_body(d)
    
    @test restored.pos == original.pos
    @test restored.mass == original.mass
end

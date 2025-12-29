module OrbiJul

include("renderer.jl")
using .Renderer

include("simulator.jl")
using .Simulator

using GLMakie
using StaticArrays

export main

function main()
    prepare_glmakie()

    # points = Observable(Point3f[])
    # prepare_render(points)

    # points[] = [(0,0,0), (1,1,1)]

    bodies = Observable([
        PhysicsBody(@SVector[0f0, 0f0, 0f0], @SVector[0f0, 0f0, 0f0], 1f0, 5f0),
        PhysicsBody(@SVector[1f0, 0f0, 0f0], @SVector[0f0, 0f0, 0f0], 1f0, 3f0),
    ])

    pos = @lift([Point3f(body.pos) for body in $(bodies)]) 
    sizes = @lift([body.size for body in $(bodies)])

    return bodies, pos
end

end

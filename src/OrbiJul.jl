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

    bodies = Observable([
        PhysicsBody(@SVector[0f0, 0f0, 0f0], @SVector[0f0, 2f0, 0f0], 10f0, 50f0),
        PhysicsBody(@SVector[1f0, 0f0, 0f0], @SVector[0f0,-2f0, 0f0], 10f0, 50f0),
    ])

    fig = prepare_render(bodies)

    dt = 0.016f0

    while isopen(fig.scene)
        step!(bodies[], dt)
        notify(bodies)
        sleep(dt)
    end

    return bodies
end

end

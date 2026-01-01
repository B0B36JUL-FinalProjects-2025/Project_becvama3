module OrbiJul

include("simulator.jl")
using .Simulator

include("renderer.jl")
using .Renderer

using GLMakie
using StaticArrays

export main

function main()
    prepare_glmakie()

    bodies = Observable([
        PhysicsBody(@SVector[0f0, 0f0, 0f0], @SVector[0f0, 2f0, 0f0], 10f0),
        PhysicsBody(@SVector[1f0, 0f0, 0f0], @SVector[0f0,-2f0, 0f0], 10f0),
    ])

    fig = prepare_render(bodies)
    
    playing = Observable(false)

    on(events(fig).keyboardbutton) do event
        if event.action == Keyboard.press || event.action == Keyboard.repeat
            if event.key == Keyboard.space
                playing[] = !playing[]
                @show playing
            end

            if event.key == Keyboard.delete
                @show "Reset"
                reset!(bodies[])
                notify(bodies)
            end
        end
    end

    dt = 0.016f0

    @async while isopen(fig.scene)
        if playing[]
            step!(bodies[], dt)
            notify(bodies)
        else
        end
        
        sleep(dt)
    end

    return bodies
end

end

module OrbiJul

include("simulator.jl")
using .Simulator

include("state_machine.jl")
using .StateMachine

include("serializer.jl")
using .Serializer

include("renderer.jl")
using .Renderer

using GLMakie
using StaticArrays

export main

function main()
    bodies = [
        PhysicsBody(@SVector[0f0, 0f0, 0f0], 
                    @SVector[0f0, 0f0, 0f0], 
                    500f0)
    ]
    state = AppState(init_bodies=bodies, dt=0.016f0)

    run_app(state)
end

function run_app(state::AppState)

    # preparation of graphical environment
    prepare_glmakie()
    fig = prepare_renderer(state)

    # preparation of control listener events
    control_events(fig, state)

    # infinite application loop
    while isopen(fig.scene)
        if state.playing[]
            state.frame += 1
            step!(state.bodies[], state.dt, state.trails[], state.frame, state.solver[])
            notify(state.bodies)
        end
        
        sleep(state.dt)
    end

end

function control_events(fig::Figure, state::AppState)
    on(events(fig).keyboardbutton) do event
        if event.action == Keyboard.press || event.action == Keyboard.repeat
            if event.key == Keyboard.space
                state.playing[] = !state.playing[]
            end

            if event.key == Keyboard.delete
                state.playing[] = false
                reset!(state.bodies[])
                notify(state.bodies)
            end
        end
    end
end

end

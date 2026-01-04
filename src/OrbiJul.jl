module OrbiJul

using StaticArrays: _transpose

include("simulator.jl")
using .Simulator

include("state_machine.jl")
using .StateMachine

include("renderer.jl")
using .Renderer

using GLMakie
using StaticArrays

export main

function main()
    prepare_glmakie()

    state = AppState(playing=false, dt=0.016f0)
    prepare_listeners!(state)

    fig = prepare_render(state)

    recompute_trajectories!(state.bodies[], state.trajectories[]; dt=state.dt)
    notify(state.trajectories)

    on(events(fig).keyboardbutton) do event
        if event.action == Keyboard.press || event.action == Keyboard.repeat
            if event.key == Keyboard.space
                state.playing[] = !state.playing[]
                @show state.playing
            end

            if event.key == Keyboard.delete
                @show "Reset"
                reset!(state.bodies[])
                state.playing[] = false
                notify(state.bodies)
            end
        end
    end

    while isopen(fig.scene)
        if state.playing[]
            state.frame += 1
            step!(state.bodies[], state.trails[], state.dt, state.frame)
            notify(state.bodies)
        end
        
        sleep(state.dt)
    end
end

end

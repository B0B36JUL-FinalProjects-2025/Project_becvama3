module StateMachine
    
using ..Simulator: PhysicsBody, recompute_trajectories!

using StaticArrays

using GLMakie

export AppState, prepare_listeners!

mutable struct AppState
    playing::Observable{Bool}

    bodies::Observable{Vector{PhysicsBody}}
    trails::Observable{Vector{Vector{Point3f}}}

    trajectories::Observable{Vector{Vector{Point3f}}}

    selected_body_index::Observable{Int}

    dt::Float32
    frame::UInt64

    function AppState(;playing::Bool=false, dt::Float32=0.016f0)
        _playing = Observable(playing)
        _bodies = Observable([
            PhysicsBody(@SVector[0f0, 0f0, 0f0], 
                        @SVector[0f0, 0f0, 0f0], 
                        1f0, 
                        RGBf(rand(), rand(), rand()))
        ])
        _trails       = Observable([Point3f[] for _ in _bodies[]])
        _trajectories = Observable([Point3f[] for _ in _bodies[]])

        _idx = Observable(0)

        new(_playing, _bodies, _trails, _trajectories, _idx, dt, 0)
    end

end

function prepare_listeners!(state::AppState)
    on(state.bodies) do _
        state.playing[] && return

        new_trajs = [Point3f[] for _ in 1:length(state.bodies[])]
        state.trajectories[] = new_trajs

        new_trails = [Point3f[] for _ in 1:length(state.bodies[])]
        state.trails[] = new_trails

        recompute_trajectories!(state.bodies[], state.trajectories[]; dt=state.dt)
        notify(state.trajectories)

        for t in state.trails[]; empty!(t); end
        notify(state.trails)
    end

    on(state.playing) do p
        if p
            # clear predictions when playing starts
            for t in state.trajectories[]; empty!(t); end
            notify(state.trajectories)
        else
            recompute_trajectories!(state.bodies[], state.trajectories[]; dt=state.dt)
            notify(state.trajectories)
        end
    end

end

end

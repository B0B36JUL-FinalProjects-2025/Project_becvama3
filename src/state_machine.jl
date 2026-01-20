module StateMachine
    
using ..Simulator: PhysicsBody, recompute_trajectories!, EulerSolver, VelocityVerletSolver

using StaticArrays

using GLMakie

export AppState

mutable struct AppState
    playing::Observable{Bool}

    bodies::Observable{Vector{PhysicsBody}}
    trails::Observable{Vector{Vector{Point3f}}}

    trajectories::Observable{Vector{Vector{Point3f}}}

    selected_body_index::Observable{Int}
    centered_body_index::Observable{Int}

    dt::Float32
    frame::UInt64

    function AppState(;init_bodies::Vector{PhysicsBody}, dt::Float32=0.016f0)
        _playing = Observable(false)
        _bodies = Observable(init_bodies)
        _trails       = Observable([Point3f[] for _ in _bodies[]])
        _trajectories = Observable([Point3f[] for _ in _bodies[]])

        s_idx = Observable(0)
        c_idx = Observable(0)

        state = new(_playing, _bodies, _trails, _trajectories, s_idx, c_idx, dt, 0)

        prepare_listeners!(state)
        return state
    end

end

function prepare_listeners!(state::AppState)
    on(state.bodies) do _
        state.playing[] && return

        new_trajs = [Point3f[] for _ in 1:length(state.bodies[])]
        state.trajectories[] = new_trajs

        new_trails = [Point3f[] for _ in 1:length(state.bodies[])]
        state.trails[] = new_trails

        recompute_trajectories!(state.bodies[], state.trajectories[]; dt=state.dt, solver=VelocityVerletSolver())
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
            recompute_trajectories!(state.bodies[], state.trajectories[]; dt=state.dt, solver=VelocityVerletSolver())
            notify(state.trajectories)
        end
    end

end

end

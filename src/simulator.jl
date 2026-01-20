module Simulator

using StaticArrays
using GLMakie
using Colors

export PhysicsBody, step!, reset!, recompute_trajectories!

abstract type  AbstractSolver end
struct EulerSolver <: AbstractSolver end
struct VerletSolver <: AbstractSolver end

const G = 10

mutable struct PhysicsBody
    startPos::SVector{3, Float32}
    startVel::SVector{3, Float32}
    pos::SVector{3, Float32}
    vel::SVector{3, Float32}
    mass::Float32
    color::RGBf

    function PhysicsBody(startPos::SVector{3, Float32}, startVel::SVector{3, Float32}, mass::Float32)
        new(startPos, 
            startVel, 
            startPos, 
            startVel, 
            mass, 
            RGBf(rand(), rand(), rand()))
    end

    function PhysicsBody(orig::PhysicsBody, new_pos::SVector{3, Float32}, new_vel::SVector{3, Float32})
        new(orig.startPos, 
            orig.startVel, 
            new_pos, 
            new_vel, 
            orig.mass, 
            orig.color)
    end
end

function reset!(bodies::Vector{PhysicsBody})
    for b in bodies
        b.pos = b.startPos
        b.vel = b.startVel
    end
end

function step!(bodies::Vector{PhysicsBody}, dt::Float32, trails::Vector{Vector{Point3f}}, frame::UInt64, solver::AbstractSolver=EulerSolver)
    physics_step!(bodies, dt, solver)

    if !isnothing(trails)
        record_trails!(bodies, trails, frame)
    end
end

function calculate_accelerations(bodies::Vector{PhysicsBody})
    accels = zeros(SVector{3, Float32}, length(bodies))

    for i in eachindex(bodies)
        bi = bodies[i]
        f_acc = SVector{3, Float32}(0,0,0)

        for j in eachindex(bodies) 
            i == j && continue

            bj = bodies[j]

            r = bi.pos - bj.pos
            dist2 = max(sum(abs2, r), 1f-4)

            # F = G * m1 * m2 / r^2
            # a = F / m1
            f_acc -= G * bj.mass * r / sqrt(dist2^3)
        end
        accels[i] = f_acc
    end

    return accels
end

function physics_step!(bodies::Vector{PhysicsBody}, dt::Float32, solver::EulerSolver)
    accels = calculate_accelerations(bodies)

    for i in eachindex(bodies)
        b = bodies[i]

        new_vel = b.vel + accels[i] * dt
        new_pos = b.pos + new_vel   * dt

        bodies[i].vel = new_vel
        bodies[i].pos = new_pos
    end
end

function physics_step!(bodies::Vector{PhysicsBody}, dt::Float32, solver::VerletSolver)
    accels = calculate_accelerations(bodies)
end

function record_trails!(bodies::Vector{PhysicsBody}, trails::Vector{Vector{Point3f}}, frame::UInt64)

    # Trail only on limited number of steps
    frame % 10 != 0 && return 

    for (i, b) in enumerate(bodies)
        push!(trails[i], Point3f(b.pos))

        if length(trails[i]) > 500
            popfirst!(trails[i])
        end
    end
end

function recompute_trajectories!(bodies::Vector{PhysicsBody}, trajectories::Vector{Vector{Point3f}}; dt::Float32, steps::UInt64=UInt64(5000))
    test_bodies = deepcopy(bodies)

    # clean trajectories
    for traj in trajectories
        empty!(traj)
    end

    for _ in 1:steps
        physics_step!(test_bodies, dt)

        for i in eachindex(test_bodies)
            push!(trajectories[i], Point3f(test_bodies[i].pos))
        end
    end
end

end


module Simulator

using StaticArrays
using GLMakie
using Colors

export PhysicsBody, step!, reset!, recompute_trajectories!
export EulerSolver, VelocityVerletSolver

abstract type  AbstractSolver end
struct EulerSolver <: AbstractSolver end
struct VelocityVerletSolver <: AbstractSolver end
struct RK4Solver <: AbstractSolver end

const G = 10

mutable struct PhysicsBody
    startPos::SVector{3, Float32}
    startVel::SVector{3, Float32}
    pos::SVector{3, Float32}
    vel::SVector{3, Float32}
    mass::Float32
    color::RGBf

    function PhysicsBody(startPos::SVector{3, Float32}, startVel::SVector{3, Float32}, mass::Float32, color=RGBf(rand(), rand(), rand()))
        new(startPos, 
            startVel, 
            startPos, 
            startVel, 
            mass, 
            color)
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

function step!(bodies::Vector{PhysicsBody}, dt::Float32, trails::Vector{Vector{Point3f}}, frame::UInt64, solver::AbstractSolver=EulerSolver())
    physics_step!(bodies, dt, solver)

    if !isnothing(trails)
        record_trails!(bodies, trails, frame)
    end
end

function get_accel(positions, masses)
    n = length(positions)
    accels = zeros(SVector{3, Float32}, n)

    for i in 1:n
        pos_i = positions[i]
        a = SVector{3, Float32}(0,0,0)
        
        for j in 1:n
            i == j && continue
            
            r = pos_i - positions[j]
            dist2 = max(sum(abs2, r), 1f-4)
            a -= G * masses[j] * r / sqrt(dist2^3)
        end
        accels[i] = a
    end
    return accels
end

function calculate_accelerations(bodies::Vector{PhysicsBody})
    pos = [b.pos for b in bodies]
    masses = [b.mass for b in bodies]
    return get_accel(pos, masses)
end

function physics_step!(bodies::Vector{PhysicsBody}, dt::Float32, ::EulerSolver)
    """
        Euler method physics step
    """

    accels = calculate_accelerations(bodies)

    for i in eachindex(bodies)
        b = bodies[i]

        new_vel = b.vel + accels[i] * dt
        new_pos = b.pos + new_vel   * dt

        bodies[i].vel = new_vel
        bodies[i].pos = new_pos
    end
end

function physics_step!(bodies::Vector{PhysicsBody}, dt::Float32, ::VelocityVerletSolver)
    """
        Implementation of the velocity verlet step based on:
        https://en.wikipedia.org/wiki/Verlet_integration#Velocity_Verlet
    """
    accels = calculate_accelerations(bodies)

    dt_half = dt/2

    # position full + half vel
    for i in eachindex(bodies)
        b = bodies[i]

        half_vel = b.vel + accels[i]*dt_half
        new_pos = b.pos + half_vel*dt

        bodies[i].pos = new_pos
        bodies[i].vel = half_vel
    end

    accels_next = calculate_accelerations(bodies)

    # velocity full
    for i in eachindex(bodies)
        b = bodies[i]

        new_vel = b.vel + accels_next[i] * dt_half
        bodies[i].vel = new_vel
    end

end

# Runge-Kutta 4 (RK4)
function physics_step!(bodies::Vector{PhysicsBody}, dt::Float32, ::RK4Solver)
    # Extract arrays for vectorized math
    x = [b.pos for b in bodies]
    v = [b.vel for b in bodies]
    m = [b.mass for b in bodies]
    
    # k1: Slope at start
    a1 = get_accel(x, m)
    v1 = v
    
    # k2: Slope at midpoint using k1
    x2 = x .+ v1 .* (0.5f0 * dt)
    # We approximate velocity at midpoint as v + a1 * 0.5dt
    v_mid1 = v .+ a1 .* (0.5f0 * dt) 
    a2 = get_accel(x2, m)
    v2 = v_mid1
    
    # k3: Slope at midpoint using k2
    x3 = x .+ v2 .* (0.5f0 * dt)
    v_mid2 = v .+ a2 .* (0.5f0 * dt)
    a3 = get_accel(x3, m)
    v3 = v_mid2
    
    # k4: Slope at end using k3
    x4 = x .+ v3 .* dt
    v_end = v .+ a3 .* dt
    a4 = get_accel(x4, m)
    v4 = v_end
    
    # Combine (Simpson's Rule)
    for i in eachindex(bodies)
        dx = (v1[i] + 2*v2[i] + 2*v3[i] + v4[i]) * (dt / 6.0f0)
        dv = (a1[i] + 2*a2[i] + 2*a3[i] + a4[i]) * (dt / 6.0f0)
        
        bodies[i].pos += dx
        bodies[i].vel += dv
    end
end

function record_trails!(bodies::Vector{PhysicsBody}, trails::Vector{Vector{Point3f}}, frame::UInt64)
    # Trail only on limited number of steps
    frame % 3 != 0 && return 

    for (i, b) in enumerate(bodies)
        push!(trails[i], Point3f(b.pos))

        if length(trails[i]) > 500
            popfirst!(trails[i])
        end
    end
end

function recompute_trajectories!(bodies::Vector{PhysicsBody}, trajectories::Vector{Vector{Point3f}}; dt::Float32, steps::UInt64=UInt64(20000), solver::AbstractSolver)
    test_bodies = deepcopy(bodies)

    # clean trajectories
    for traj in trajectories
        empty!(traj)
    end
    
    for _ in 1:steps
        physics_step!(test_bodies, dt, solver)

        for i in eachindex(test_bodies)
            push!(trajectories[i], Point3f(test_bodies[i].pos))
        end
    end
end

end


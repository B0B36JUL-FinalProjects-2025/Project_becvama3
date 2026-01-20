module Simulator

using StaticArrays
using GLMakie
using Colors

export PhysicsBody, step!, reset!, recompute_trajectories!

mutable struct PhysicsBody
    startPos::SVector{3, Float32}
    startVel::SVector{3, Float32}
    pos::SVector{3, Float32}
    vel::SVector{3, Float32}
    mass::Float32
    color::RGBf
    center::Bool

    function PhysicsBody(startPos::SVector{3, Float32}, startVel::SVector{3, Float32}, mass::Float32)
        new(startPos, 
            startVel, 
            startPos, 
            startVel, 
            mass, 
            RGBf(rand(), rand(), rand()), 
            false)
    end

    function PhysicsBody(orig::PhysicsBody, new_pos::SVector{3, Float32}, new_vel::SVector{3, Float32})
        new(orig.startPos, 
            orig.startVel, 
            new_pos, 
            new_vel, 
            orig.mass, 
            orig.color,
            orig.center)
    end
end

const G = 10

function reset!(bodies::Vector{PhysicsBody})
    for b in bodies
        b.pos = b.startPos
        b.vel = b.startVel
    end
end

function step!(bodies::Vector{PhysicsBody}, trails::Union{Vector{Vector{Point3f}}, Nothing}, dt::Float32, frame::UInt64)
    _bodies = similar(bodies)

    for i in eachindex(bodies)
        bi = bodies[i]
        f_acc = SVector{3, Float32}(0,0,0)

        for j in eachindex(bodies) 
            if i == j 
                continue
            end 

            bj = bodies[j]

            r = bi.pos - bj.pos
            dist2 = max(sum(abs2, r), 1f-4)
            f_acc -= G * bj.mass * r / sqrt(dist2^3)
        end
        
        vel = bi.vel + f_acc*dt
        pos = bi.pos + vel*dt

        _bodies[i] = PhysicsBody(bi, pos, vel)
    end

    bodies .= _bodies

    isnothing(trails) && return
    frame % 10 != 0 && return # Trail only on limited number of steps

    for (i, b) in enumerate(bodies)
        push!(trails[i], Point3f(b.pos))

        if length(trails[i]) > 500
            popfirst!(trails[i])
        end
    end
end

function recompute_trajectories!(bodies, trajectories; dt, steps=1000)
    test_bodies = deepcopy(bodies)

    for traj in trajectories
        empty!(traj)
    end

    for _ in 1:steps
        step!(test_bodies, nothing, dt, UInt64(0))
        for i in eachindex(test_bodies)
            push!(to_value(trajectories)[i], Point3f(test_bodies[i].pos))
        end
    end
end

end


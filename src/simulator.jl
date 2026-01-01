module Simulator

using StaticArrays

export PhysicsBody, step!, reset!

mutable struct PhysicsBody
    startPos::SVector{3, Float32}
    startVel::SVector{3, Float32}
    pos::SVector{3, Float32}
    vel::SVector{3, Float32}
    mass::Float32

    function PhysicsBody(startPos::SVector{3, Float32}, startVel::SVector{3, Float32}, mass::Float32)
        new(startPos, startVel, startPos, startVel, mass)
    end

    function PhysicsBody(orig::PhysicsBody, new_pos::SVector{3, Float32}, new_vel::SVector{3, Float32})
        new(orig.startPos, orig.startVel, new_pos, new_vel, orig.mass)
    end
end

const G = 10

function reset!(bodies::Vector{PhysicsBody})
    for b in bodies
        b.pos = b.startPos
        b.vel = b.startVel
    end
end

function step!(bodies::Vector{PhysicsBody}, dt::Float32)
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

    # UPDATE old ones with new ones
    bodies .= _bodies
end

end

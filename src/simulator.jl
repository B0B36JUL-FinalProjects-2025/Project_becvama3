module Simulator

using StaticArrays

export step!, PhysicsBody

struct PhysicsBody
    pos::SVector{3, Float32}
    vel::SVector{3, Float32}
    mass::Float32
    size::Float32 end

const G = 1
# https://alvinng4.github.io/grav_sim/5_steps_to_n_body_simulation/step2/
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

        _bodies[i] = PhysicsBody(pos, vel, bi.mass, bi.size)
    end

    # UPDATE old ones with new ones
    bodies .= _bodies
end

end

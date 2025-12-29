module Simulator

using StaticArrays

export PhysicsBody

struct PhysicsBody
    pos::SVector{3, Float64}
    vel::SVector{3, Float64}
    mass::Float32
    size::Float32
end

end

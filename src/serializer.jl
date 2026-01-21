module Serializer

using JSON
using NativeFileDialog
using StaticArrays
using Colors
using ..Simulator: PhysicsBody

export save_scenario, load_scenario_dialog

function body_to_dict(b::PhysicsBody)
    return Dict(
        "pos" => [b.pos[1], b.pos[2], b.pos[3]],
        "vel" => [b.vel[1], b.vel[2], b.vel[3]],
        "mass" => b.mass,
        "color" => [red(b.color), green(b.color), blue(b.color)]
    )
end

function dict_to_body(d::AbstractDict)
    pos = SVector{3, Float32}(d["pos"]...)
    vel = SVector{3, Float32}(d["vel"]...)
    mass = Float32(d["mass"])
    
    c_arr = d["color"]
    color = RGB{Float32}(c_arr[1], c_arr[2], c_arr[3])

    return PhysicsBody(pos, vel, mass, color)
end

function save_scenario(bodies::Vector{PhysicsBody})
    path = save_file("examples"; filterlist="json")
    
    if path != "" && !isempty(path)
        # add .json extension if not already 
        if !endswith(path, ".json")
            path *= ".json"
        end

        data = [body_to_dict(b) for b in bodies]
        
        open(path, "w") do f
            JSON.print(f, data, 4) 
        end
        println("Saved to: $path")
    end
end

function load_scenario_dialog()
    path = pick_file("examples"; filterlist="json")
    
    if path != "" && !isempty(path)
        try
            raw_data = JSON.parsefile(path)
            new_bodies = [dict_to_body(d) for d in raw_data]
            return new_bodies
        catch e
            println("Error loading JSON: ", e)
            return nothing
        end
    end
    return nothing
end

end

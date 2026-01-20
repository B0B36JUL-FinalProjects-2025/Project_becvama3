module Renderer

using GLMakie
using Colors
using StaticArrays

using ..Simulator: PhysicsBody, reset!
using ..StateMachine: AppState

export prepare_glmakie, prepare_renderer

struct UIElements
    cb_wireframe::Toggle
    sl_wireframe::Slider
end

function prepare_glmakie()
    GLMakie.activate!()
    GLMakie.closeall()
end

function prepare_renderer(state::AppState)
    fig = Figure(backgroundcolor = :gray20)
    ax = LScene(fig[1, 1], show_axis=false, scenekw = (backgroundcolor = :gray20, clear=true))
    grid = GridLayout(fig[2,1]; tellwidth=false) 

    uielements = uiRenderer(grid, state)
    bodyRenderer(ax, state)
    proxyRenderer(ax, state)
    wireframeRenderer(ax, state, uielements)
    trailRenderer(ax, state)

    display(fig)
    return fig
end

function bodyInspector(menu::Menu, inspector_grid::GridLayout, state::AppState, swatch_color::Observable)

    inspector_grid.halign = :left

    Label(inspector_grid[1, 1], "Pos (X/Y):")
    sl_xpos = Slider(inspector_grid[1, 2], range=-100f0:0.1f0:100f0, width=250)
    sl_ypos = Slider(inspector_grid[1, 3], range=-100f0:0.1f0:100f0, width=250)

    Label(inspector_grid[2, 1], "Vel (X/Y):")
    sl_xvel = Slider(inspector_grid[2, 2], range=-10f0:0.1f0:10f0, width=250)
    sl_yvel = Slider(inspector_grid[2, 3], range=-10f0:0.1f0:10f0, width=250)

    Label(inspector_grid[3, 1], "Mass")
    sl_mass = Slider(inspector_grid[3, 2], range=1f0:1f0:100f0, width=250, tellwidth=false)

    Label(inspector_grid[4, 1], "Centered")
    toggle_centered = Toggle(inspector_grid[4,2], active=false, halign=:right, tellwidth=false)

    on(state.selected_body_index) do idx
        if !checkbounds(Bool, state.bodies[], idx)
            swatch_color[] = RGBAf(0,0,0,0)
            return nothing
        end

        b = state.bodies[][idx]

        set_close_to!(sl_xpos, b.startPos[1])
        set_close_to!(sl_ypos, b.startPos[2])
        set_close_to!(sl_xvel, b.startVel[1])
        set_close_to!(sl_yvel, b.startVel[2])
        set_close_to!(sl_mass, b.mass)

        toggle_centered.active[] = (idx == state.centered_body_index[])
        swatch_color[] = b.color

        @show b
    end

    on(toggle_centered.active) do centered 
        idx = state.selected_body_index[]
        !checkbounds(Bool, state.bodies[], idx) && return nothing

        if centered # if switched ON
            # center selected one
            state.centered_body_index[] = idx
        elseif idx == state.centered_body_index[] # if switched OFF
            state.centered_body_index[] = 0
        end

        notify(state.bodies)
    end

    function update_body_param(f)
        idx = state.selected_body_index[]
        !checkbounds(Bool, state.bodies[], idx) && return nothing

        state.playing[] = false

        f(state.bodies[][idx]) 
        reset!(state.bodies[]) 
        notify(state.bodies)   
    end

    on(sl_xpos.value) do p; update_body_param(b -> b.startPos = @SVector[p, b.startPos[2], b.startPos[3]]) end
    on(sl_ypos.value) do p; update_body_param(b -> b.startPos = @SVector[b.startPos[1], p, b.startPos[3]]) end
    on(sl_xvel.value) do v; update_body_param(b -> b.startVel = @SVector[v, b.startVel[2], b.startVel[3]]) end
    on(sl_yvel.value) do v; update_body_param(b -> b.startVel = @SVector[b.startVel[1], v, b.startVel[3]]) end
    on(sl_mass.value) do m; update_body_param(b -> b.mass = m) end
end

function uiRenderer(grid::GridLayout, state::AppState)
    body_count = Observable(length(state.bodies[]))
    on(state.bodies) do bodies
        if body_count[] != length(bodies)
            body_count[] = length(bodies)
        end
    end

    bodyOptions = @lift([string(i) for i in 1:$body_count])

    menu_row = GridLayout(tellwidth=false, halign=:left)
    grid[1,1] = menu_row

    swatch_color = Observable{RGBAf}(RGBAf(0,0,0,0))
    Box(menu_row[1,1], color=swatch_color, width=32, cornerradius=100)
    menu = Menu(menu_row[1, 2], options=bodyOptions, default=nothing)

    btn_grid = GridLayout(tellwidth=false, halign=:left)
    menu_row[1, 3] = btn_grid

    # When menu changes, update our index
    on(menu.selection) do selection
        @show selection
        if isnothing(selection) 
            state.selected_body_index[] = 0
            return 
        end

        state.playing[] = false

        idx = parse(Int, selection)
        state.selected_body_index[] = idx
    end

    bAdd    = Button(btn_grid[1, 1], label = "+", labelcolor=:white, font=:bold, buttoncolor = RGBAf(0,1,0, 0.5))
    bRemove = Button(btn_grid[1, 2], label = "-", labelcolor=:white, font=:bold, buttoncolor = RGBAf(1,0,0, 0.8))

    on(bAdd.clicks) do click 
        state.playing[] = false

        push!(state.bodies[], 
              PhysicsBody(@SVector[0f0, 0f0, 0f0], 
                          @SVector[0f0, 0f0, 0f0], 
                          1f0)
             )

        reset!(state.bodies[])
        notify(state.bodies)
    end
    on(bRemove.clicks) do click 
        isempty(state.bodies[]) && return nothing

        idx = state.selected_body_index[]
        !checkbounds(Bool, state.bodies[], idx) && return nothing

        state.playing[] = false
        deleteat!(state.bodies[], idx)
        reset!(state.bodies[])

        menu.selection[] = nothing

        notify(state.bodies)

        # RESELECT on remove is kinda iffy - choosing to discard selecion on remove
        # if !isempty(state.bodies[]) 
        #     menu.selection[] = "1"
        # end
    end

    Box(grid[2, 1:2], color = :gray) 
    inspector_grid = GridLayout(grid[2, 1:2], tellwidth=false)

    bodyInspector(menu, inspector_grid, state, swatch_color)

    toggle_wireframe = Toggle(grid[3,1], active=true, halign=:right, tellwidth=false)
    Label(grid[3,2], "Show Gravitational Potential", halign=:left, tellwidth=false)

    sl_wireframe = Slider(grid[4,1], range=0.1f0:0.1:2.5f0, startvalue=1, snap=true, width=100, halign=:right, tellwidth=false)
    Label(grid[4,2], "Wireframe scale", halign=:left, tellwidth=false)

    return UIElements(toggle_wireframe, sl_wireframe)
end


function _get_center_pos(bodies::Vector{PhysicsBody}, c_idx::Int)
    """
        Method for finding the centered body to get the offset vector for rendering others
    """
    center_pos = if checkbounds(Bool, bodies, c_idx)
        Point3f(bodies[c_idx].pos)
    else
        Point3f(0)
    end

    return center_pos
end

function _get_reference_trail(trails::Vector{Vector{Point3f}}, c_idx::Int)
    """
        Method for finding the reference trail to get the offset vector for rendering
    """
    ref_trail = if checkbounds(Bool, trails, c_idx)
        trails[c_idx]
    else
        nothing
    end

    return ref_trail
end

function bodyRenderer(ax::LScene, state::AppState)
    pos = lift(state.bodies) do bodies 
        center_pos = _get_center_pos(bodies, state.centered_body_index[])
        
        return [Point3f(body.pos) - center_pos for body in bodies]
    end

    # pos = @lift([Point3f(body.pos) for body in $(state.bodies)]) 

    power::Float32 = 1/3
    sizes = @lift([body.mass^power for body in $(state.bodies)])

    body_colors = @lift([body.color for body in $(state.bodies)])

    sphere = Sphere(Point3f(0), 1f0)
    
    meshscatter!(
        ax,
        pos;
        marker = sphere,
        markersize = sizes,
        color = body_colors,
        shading = true
    )

    # highlight the selected body
    selection_geometry = lift(state.playing, state.bodies, state.selected_body_index) do playing, bodies, idx
        if playing || !checkbounds(Bool, bodies, idx)
            return Sphere(Point3f(0), 0f0)
        end
        center_pos = _get_center_pos(bodies, state.centered_body_index[])

        b = bodies[idx]
        
        pos = Point3f(b.pos) - center_pos
        size = b.mass^power * 1.05f0 

        return Sphere(pos, size)
    end

    wireframe!(ax, selection_geometry; color=:red, linewidth=1, alpha=0.2)
end

function proxyRenderer(ax::LScene, state::AppState)
    """
        Forward preview renderer
    """
    scene_trajectories = lift(state.trajectories, state.centered_body_index) do trajs, c_idx
        points = Point3f[]

        ref_traj = _get_reference_trail(trajs, c_idx)

        for t in trajs
            for i in eachindex(t)
                pt = t[i]
                if !isnothing(ref_traj)
                    pt -= ref_traj[i]
                end
                
                push!(points, pt)
            end

            # Split separate bodies with NaN
            push!(points, Point3f(NaN, NaN, NaN))
        end
        return points
    end

    lines!(
        ax,
        scene_trajectories;
        color = (:white, 0.3),
        linewidth = 1,
        transparency = true
    )
end


function wireframeRenderer(ax::LScene, state::AppState, uielements::UIElements)
    function create_grid(step::Float64)
        x = collect(-25:step:25)
        y = collect(-25:step:25)
        z = zeros(Float32, length(x), length(y))
        return x,y,z
    end

    wireframe_enabled = uielements.cb_wireframe.active
    slider = uielements.sl_wireframe.value

    grid_geom = lift(slider) do step
        x, y, z = create_grid(step)
        return (x,y,z)
    end

    x_obs = @lift($grid_geom[1])
    y_obs = @lift($grid_geom[2])

    z = lift(state.bodies, grid_geom, wireframe_enabled) do bodies, (x,y,zbuf), enabled
        fill!(zbuf, -1f0)
        !enabled && return zbuf

        center_pos = _get_center_pos(bodies, state.centered_body_index[])

        for b in bodies
            rel_pos = b.pos - center_pos

            for j in eachindex(y), i in eachindex(x)
                dx = x[i] - rel_pos[1]
                dy = y[j] - rel_pos[2]
                dist2 = max(dx*dx + dy*dy, 1e-4)

                # Grav potential
                zbuf[i, j] -= b.mass / sqrt(dist2)
            end
        end
        
        # zbuf *= 1 # This needs to be here for some reason
        # zbuf .= clamp.(zbuf, -20f0, -1f0)
        clamp!(zbuf, -20f0, -1f0)
        return copy(zbuf)
    end

    wireframe!(ax, x_obs, y_obs, z, visible=wireframe_enabled, linestyle=(:dot, :loose))
end

function trailRenderer(ax::LScene, state::AppState)
    """
        Trail renderer showing the trajectory of the body with its own color
    """

    scene_data = lift(state.trails, state.bodies, state.centered_body_index) do trails, bodies, c_idx
        points = Point3f[]
        colors = RGBAf[]

        ref_traj = _get_reference_trail(trails, c_idx)

        for (i, t) in enumerate(trails)
            n_points = length(t)
            if n_points == 0; continue; end

            r, g, b = Colors.red(bodies[i].color), Colors.green(bodies[i].color), Colors.blue(bodies[i].color)

            for j in reverse(eachindex(t))
                pt = t[j]

                if !isnothing(ref_traj)
                    pt -= ref_traj[j]
                end

                alpha = max(Float32(j) / Float32(n_points), 0.01)
                vertex_color = RGBAf(r, g, b, alpha)

                push!(points, pt)
                push!(colors, vertex_color)
            end

            # NaN break to separate different bodies lines 
            push!(points, Point3f(NaN))
            push!(colors, RGBAf(0,0,0,0)) 
        end
        return (points, colors)
    end

    P = @lift($scene_data[1])
    C = @lift($scene_data[2])

    # Draw the tails
    lines!(ax, P; color = C, linewidth = 2.5, transparency = true)
end

end

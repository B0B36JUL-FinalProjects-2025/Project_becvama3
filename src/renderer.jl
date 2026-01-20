module Renderer

using GLMakie
using Colors
using StaticArrays

using ..Simulator: PhysicsBody, reset!
using ..StateMachine: AppState

export prepare_glmakie, prepare_render

struct UIElements
    cb_wireframe::Toggle
    sl_wireframe::Slider
end

function prepare_glmakie()
    GLMakie.activate!()
    GLMakie.closeall()
end

function prepare_render(state::AppState)
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

    on(state.selected_body_index) do idx
        if !checkbounds(Bool, state.bodies[], idx)
            swatch_color[] = RGBAf(0,0,0,0)
            return nothing
        end

        b = state.bodies[][idx]
        c = state.bodies[][idx].color

        set_close_to!(sl_xpos, b.startPos[1])
        set_close_to!(sl_ypos, b.startPos[2])
        set_close_to!(sl_xvel, b.startVel[1])
        set_close_to!(sl_yvel, b.startVel[2])
        set_close_to!(sl_mass, b.mass)

        swatch_color[] = c
    end

    function update_body_param(f)
        idx = state.selected_body_index[]
        !checkbounds(Bool, state.bodies[], idx) && return nothing

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
                          1f0, 
                          RGBf(rand(), rand(), rand()))
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

function bodyRenderer(ax::LScene, state::AppState)
    pos = @lift([Point3f(body.pos) for body in $(state.bodies)]) 

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
        b = bodies[idx]
        
        pos = Point3f(b.pos)
        size = b.mass^power * 1.05f0 

        return Sphere(pos, size)
    end

    wireframe!(ax, selection_geometry; color=:red, linewidth=1, alpha=0.2)
end

function proxyRenderer(ax::LScene, state::AppState)
    """
        Forward preview renderer
    """
    scene_trajectories = lift(state.trajectories) do trajs
        points = Point3f[]
        for t in trajs
            append!(points, t)
            # To split different proxies of different bodies
            push!(points, Point3f(NaN,NaN,NaN))
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
        if !enabled
            return zbuf
        end

        for b in bodies
            for j in eachindex(y), i in eachindex(x)
                dx = x[i] - b.pos[1]
                dy = y[j] - b.pos[2]
                dist2 = max(dx*dx + dy*dy, 1e-4)

                # Grav potential
                zbuf[i, j] -= b.mass / sqrt(dist2)
            end
        end
        
        zbuf *= 1 # This needs to be here for some reason
        zbuf .= clamp.(zbuf, -30f0, -1f0)
        return zbuf
    end

    wireframe!(ax, x_obs, y_obs, z, visible=wireframe_enabled, linestyle=(:dot, :loose))
end

function trailRenderer(ax::LScene, state::AppState)
    """
        Trail renderer showing the trajectory of the body with its own color
    """

    scene_data = lift(state.trails, state.bodies) do current_trails, current_bodies
        points = Point3f[]
        colors = RGBAf[]

        for (i, t) in enumerate(current_trails)
                n_points = length(t)
                if n_points == 0; continue; end

                base_c = current_bodies[i].color
                r, g, b = Colors.red(base_c), Colors.green(base_c), Colors.blue(base_c)

                for (j, point) in enumerate(t)
                    alpha = max(Float32(j) / Float32(n_points), 0.01)

                    vertex_color = RGBAf(r, g, b, alpha)

                    push!(points, point)
                    push!(colors, vertex_color)
                end

                # Add NaN break to separate this line from the next body's line
                push!(points, Point3f(NaN))
                # The color at the NaN point doesn't matter, just needs to match type
                push!(colors, RGBAf(0,0,0,0)) 
            end
            return (points, colors)
        end

    P = @lift($scene_data[1])
    C = @lift($scene_data[2])

    # Draw the tails
    lines!(ax, P; color = C, linewidth = 2.5, transparency = false)
end

end

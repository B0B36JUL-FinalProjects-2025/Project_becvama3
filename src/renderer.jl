module Renderer

using GLMakie
using Colors
using StaticArrays

using ..Simulator: PhysicsBody, reset!, EulerSolver, VelocityVerletSolver
using ..StateMachine: AppState
using ..Serializer: save_scenario, load_scenario_dialog

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
    fig = Figure(backgroundcolor=:gray20)
    ax = LScene(fig[1, 1], show_axis=false, scenekw=(backgroundcolor=:gray20, clear=true))
    grid = GridLayout(fig[2, 1]; tellwidth=false)

    uielements = uiRenderer(grid, state)
    bodyRenderer(ax, state)
    proxyRenderer(ax, state)
    wireframeRenderer(ax, state, uielements)
    trailRenderer(ax, state)

    display(fig)
    return fig
end

function _panel_body_inspector(inspector_grid::GridLayout, state::AppState, swatch_color::Observable)
    """
    Panel creating helper
    """

    inspector_grid.halign = :left

    Label(inspector_grid[1, 1], "Pos (X/Y):", color=:white)
    sl_xpos = Slider(inspector_grid[1, 2], range=-100.0f0:0.1f0:100.0f0, width=250)
    sl_ypos = Slider(inspector_grid[1, 3], range=-100.0f0:0.1f0:100.0f0, width=250)

    Label(inspector_grid[2, 1], "Vel (X/Y):", color=:white)
    sl_xvel = Slider(inspector_grid[2, 2], range=-50.0f0:0.1f0:50.0f0, width=250)
    sl_yvel = Slider(inspector_grid[2, 3], range=-50.0f0:0.1f0:50.0f0, width=250)

    Label(inspector_grid[3, 1], "Mass", color=:white)
    sl_mass = Slider(inspector_grid[3, 2], range=0.1f0:0.1f0:1000.0f0, width=250, tellwidth=false)

    Label(inspector_grid[4, 1], "Centered", color=:white)
    toggle_centered = Toggle(inspector_grid[4, 2], active=false, halign=:left, tellwidth=false)

    on(state.selected_body_index) do idx
        if !checkbounds(Bool, state.bodies[], idx)
            swatch_color[] = RGBAf(0, 0, 0, 0)
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

    on(sl_xpos.value) do p
        update_body_param(b -> b.startPos = @SVector[p, b.startPos[2], b.startPos[3]])
    end
    on(sl_ypos.value) do p
        update_body_param(b -> b.startPos = @SVector[b.startPos[1], p, b.startPos[3]])
    end
    on(sl_xvel.value) do v
        update_body_param(b -> b.startVel = @SVector[v, b.startVel[2], b.startVel[3]])
    end
    on(sl_yvel.value) do v
        update_body_param(b -> b.startVel = @SVector[b.startVel[1], v, b.startVel[3]])
    end
    on(sl_mass.value) do m
        update_body_param(b -> b.mass = m)
    end
end

function _panel_body_selection(select_grid::GridLayout, state::AppState)
    """
    Panel creating helper
    """
    body_count = Observable(length(state.bodies[]))
    on(state.bodies) do bodies
        if body_count[] != length(bodies)
            body_count[] = length(bodies)
        end
    end

    bodyOptions = @lift([string(i) for i in 1:$body_count])

    Label(select_grid[1, 1], "Body Selection:", fontsize=16, color=:white)
    swatch_color = Observable{RGBAf}(RGBAf(0, 0, 0, 0))
    Box(select_grid[1, 2], color=swatch_color, width=32, cornerradius=100)
    menu = Menu(select_grid[1, 3], options=bodyOptions, default=nothing, width=150)

    btn_grid = GridLayout(tellwidth=false, halign=:left)
    select_grid[1, 4] = btn_grid

    # When menu changes, update our index
    on(menu.selection) do selection
        if isnothing(selection)
            state.selected_body_index[] = 0
            return
        end

        state.playing[] = false

        idx = parse(Int, selection)
        state.selected_body_index[] = idx
    end

    bAdd = Button(btn_grid[1, 1], label="+", width=30, labelcolor=:white, font=:bold, buttoncolor=RGBAf(0, 1, 0, 0.5))
    bRemove = Button(btn_grid[1, 2], label="-", width=30, labelcolor=:white, font=:bold, buttoncolor=RGBAf(1, 0, 0, 0.8))

    on(bAdd.clicks) do click
        state.playing[] = false

        push!(state.bodies[],
            PhysicsBody(@SVector[0.0f0, 0.0f0, 0.0f0],
                @SVector[0.0f0, 0.0f0, 0.0f0],
                500.0f0)
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
    end

    return swatch_color
end

function _panel_sim_inspector(sim_grid::GridLayout, state::AppState)
    """
    Panel creating helper
    """
    solver_opts = ["Euler Method", "Velocity Verlet"]

    Label(sim_grid[1, 1], "Scenarios", color=:white)
    btn_grid = GridLayout(tellwidth=false, halign=:center)
    sim_grid[1, 2] = btn_grid
    bSave = Button(btn_grid[1, 1], label="Save")
    bLoad = Button(btn_grid[1, 2], label="Load")

    on(bSave.clicks) do _
        state.playing[] = false
        reset!(state.bodies[])
        notify(state.bodies)

        save_scenario(state.bodies[])
    end

    on(bLoad.clicks) do _
        # Open dialog and parse JSON
        new_bodies = load_scenario_dialog()

        # If user picked a valid file (didn't cancel):
        if !isnothing(new_bodies)
            state.playing[] = false

            # Update State
            state.bodies[] = new_bodies
            state.selected_body_index[] = 1
            state.centered_body_index[] = 0

            # Force Refresh
            reset!(state.bodies[])
            notify(state.bodies)
        end
    end


    Label(sim_grid[2, 1], "Solver Selection", color=:white)
    solver_menu = Menu(sim_grid[2, 2], options=solver_opts, default="Velocity Verlet", width=200)

    on(solver_menu.selection) do selection
        if selection == "Euler Method"
            state.solver[] = EulerSolver()
        elseif selection == "Velocity Verlet"
            state.solver[] = VelocityVerletSolver()
        end
    end

    Label(sim_grid[3, 1], "Show Gravitational Potential", color=:white)
    toggle_wireframe = Toggle(sim_grid[3, 2], active=true)

    Label(sim_grid[4, 1], "Wireframe scale", color=:white)
    sl_wireframe = Slider(sim_grid[4, 2], range=1.0f0:0.1:10.0f0, startvalue=5, snap=true, width=100)

    return UIElements(toggle_wireframe, sl_wireframe)
end


function uiRenderer(grid::GridLayout, state::AppState)
    function create_panel(row, col)
        Box(grid[row, col], color=:gray25, cornerradius=8)
        container = GridLayout(grid[row, col], alignmode=Outside(10))

        return GridLayout(container[1, 1], tellwidth=false, halign=:left)
    end

    # --- Body selection ---
    select_grid = create_panel(1, 1)
    swatch_color = _panel_body_selection(select_grid, state)

    # --- Body Attributes ---
    attribute_grid = create_panel(2, 1)
    _panel_body_inspector(attribute_grid, state, swatch_color)

    # --- Sim Attributes ---
    sim_grid = create_panel(3, 1)
    ui_elements::UIElements = _panel_sim_inspector(sim_grid, state)

    return ui_elements
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

    # based on solid planet scale ratios
    power::Float32 = 1 / 3
    sizes = @lift([body.mass^power for body in $(state.bodies)])

    body_colors = @lift([body.color for body in $(state.bodies)])

    sphere = Sphere(Point3f(0), 1.0f0)

    meshscatter!(
        ax,
        pos;
        marker=sphere,
        markersize=sizes,
        color=body_colors,
        shading=true
    )

    # highlight the selected body
    selection_geometry = lift(state.playing, state.bodies, state.selected_body_index) do playing, bodies, idx
        if playing || !checkbounds(Bool, bodies, idx)
            return Sphere(Point3f(0), 0.0f0)
        end
        center_pos = _get_center_pos(bodies, state.centered_body_index[])

        b = bodies[idx]

        pos = Point3f(b.pos) - center_pos
        size = b.mass^power * 1.1f0

        return Sphere(pos, size)
    end

    wireframe!(ax, selection_geometry; color=:red, linewidth=2, alpha=0.5)
end

function proxyRenderer(ax::LScene, state::AppState)
    """
        Forward preview renderer
    """
    scene_data = lift(state.trajectories, state.centered_body_index) do trajs, c_idx
        points = Point3f[]
        colors = RGBAf[]

        ref_traj = _get_reference_trail(trajs, c_idx)

        for (i, t) in enumerate(trajs)

            r, g, b = Colors.red(state.bodies[][i].color), Colors.green(state.bodies[][i].color), Colors.blue(state.bodies[][i].color)

            for i in eachindex(t)
                vertex_color = RGBAf(r, g, b, 0.3)

                pt = t[i]
                if !isnothing(ref_traj)
                    pt -= ref_traj[i]
                end

                push!(points, pt)
                push!(colors, vertex_color)
            end

            # Split separate bodies with NaN
            push!(points, Point3f(NaN, NaN, NaN))
            push!(colors, RGBAf(0, 0, 0, 0))
        end
        return (points, colors)
    end

    scene_trajectories = @lift($scene_data[1])
    colors = @lift($scene_data[2])

    lines!(
        ax,
        scene_trajectories;
        color=colors,
        linewidth=4,
        transparency=true
    )
end


function wireframeRenderer(ax::LScene, state::AppState, uielements::UIElements)
    function create_grid(step::Float64)
        x = collect(-100:step:100)
        y = collect(-100:step:100)
        z = zeros(Float32, length(x), length(y))
        return x, y, z
    end

    wireframe_enabled = uielements.cb_wireframe.active
    slider = uielements.sl_wireframe.value

    grid_geom = lift(slider) do step
        x, y, z = create_grid(step)
        return (x, y, z)
    end

    x_obs = @lift($grid_geom[1])
    y_obs = @lift($grid_geom[2])

    z = lift(state.bodies, grid_geom, wireframe_enabled) do bodies, (x, y, zbuf), enabled
        fill!(zbuf, -1.0f0)
        # !enabled && return zbuf

        center_pos = _get_center_pos(bodies, state.centered_body_index[])

        for b in bodies
            rel_pos = b.pos - center_pos

            for j in eachindex(y), i in eachindex(x)
                dx = x[i] - rel_pos[1]
                dy = y[j] - rel_pos[2]
                dist2 = max(dx * dx + dy * dy, 1e-4)

                # Grav potential
                zbuf[i, j] -= b.mass / sqrt(dist2)
            end
        end

        # zbuf *= 1 # This needs to be here for some reason
        # zbuf .= clamp.(zbuf, -20f0, -1f0)
        clamp!(zbuf, -50.0f0, -1.0f0)
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
            if n_points == 0
                continue
            end

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
            push!(colors, RGBAf(0, 0, 0, 0))
        end
        return (points, colors)
    end

    P = @lift($scene_data[1])
    C = @lift($scene_data[2])

    # Draw the tails
    lines!(ax, P; color=C, linewidth=2.5, transparency=true)
end

end

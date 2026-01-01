module Renderer

using GLMakie
using StaticArrays

using ..Simulator: PhysicsBody, reset!   # ← THIS is the key line

export prepare_glmakie, prepare_render

struct UIElements
    cb_wireframe::Toggle
    sl_wireframe::Slider
end

function prepare_glmakie()
    GLMakie.activate!()
    GLMakie.closeall()
end

function prepare_render(bodies::Observable)
    fig = Figure(backgroundcolor = :gray20)
    ax = LScene(fig[1, 1], show_axis=false, scenekw = (backgroundcolor = :gray20, clear=true))
    grid = GridLayout(fig[2,1]; tellwidth=false) 

    uielements = uiRenderer(grid, bodies)
    bodyRenderer(fig, ax, bodies, uielements)
    wireframeRenderer(fig, ax, bodies, uielements)

    display(fig)
    return fig
end

function bodyInspector(menu::Menu, inspector_grid::GridLayout, bodies::Observable, selected_index::Observable)

    inspector_grid.halign = :left

    Label(inspector_grid[1, 1], "Start Position:")

    Label(inspector_grid[1, 2], "X: ")
    sl_xpos = Slider(inspector_grid[1, 3], range=-100f0:0.1f0:100f0, width=500)

    Label(inspector_grid[1, 4], "Y: ")
    sl_ypos = Slider(inspector_grid[1, 5], range=-100f0:0.1f0:100f0, width=500)

    Label(inspector_grid[2, 1], "Start Velocity:")
    Label(inspector_grid[2, 2], "X: ")
    sl_xvel = Slider(inspector_grid[2, 3], range=-10f0:0.1f0:10f0, width=150)
    Label(inspector_grid[2, 4], "Y: ")
    sl_yvel = Slider(inspector_grid[2, 5], range=-10f0:0.1f0:10f0, width=150)

    Label(inspector_grid[3, 1], "Mass")
    sl_mass = Slider(inspector_grid[3, 2], range=1f0:1f0:100f0, width=200, tellwidth=false, halign=:left)

    # --- SECTION 3: WIRING IT UP (The "Data Binding") ---
    on(selected_index) do idx
        current_body = bodies[][idx]

        set_close_to!(sl_xpos, current_body.startPos[1])
        set_close_to!(sl_ypos, current_body.startPos[2])

        set_close_to!(sl_xvel, current_body.startVel[1])
        set_close_to!(sl_yvel, current_body.startVel[2])
        # sl_mass.value = current_body.mass 
        set_close_to!(sl_mass, current_body.mass)
        # lbl_mass_val.text[] = string(current_body.mass)
    end

    on(sl_xpos.value) do value
        isnothing(menu.selection[]) && return nothing

        idx = selected_index[]
        _p = bodies[][idx].startPos

        bodies[][idx].startPos = @SVector[value, _p[2], _p[3]]
        reset!(bodies[])
        notify(bodies)
    end

    on(sl_ypos.value) do value
        isnothing(menu.selection[]) && return nothing

        idx = selected_index[]
        _p = bodies[][idx].startPos

        bodies[][idx].startPos = @SVector[_p[1], value, _p[3]]
        reset!(bodies[])
        notify(bodies)
    end

    on(sl_xvel.value) do value
        isnothing(menu.selection[]) && return nothing
        
        idx = selected_index[]
        _v = bodies[][idx].startVel

        bodies[][idx].startVel = @SVector[value, _v[2], _v[3]]
        reset!(bodies[])
        notify(bodies)
    end

    on(sl_yvel.value) do value
        isnothing(menu.selection[]) && return nothing

        idx = selected_index[]
        _v = bodies[][idx].startVel

        bodies[][idx].startVel = @SVector[_v[1], value, _v[3]]
        reset!(bodies[])
        notify(bodies)
    end
    
    on(sl_mass.value) do mass
        isnothing(menu.selection[]) && return nothing

        idx = selected_index[]
        bodies[][idx].mass = mass

        reset!(bodies[])
        notify(bodies)
    end

end

function uiRenderer(grid::GridLayout, bodies::Observable)
    selected_index = Observable(1)

    bodyCount = @lift(length($bodies))
    bodyOptions = @lift([string(i) for i in 1:$bodyCount])

    menu = Menu(grid[1, 1], options = bodyOptions, width=200, halign=:left, default="1")
    # b1 = Button(grid[1, 2], label="+", buttoncolor=:blue, tellwidth=false)
    # b2 = Button(grid[1, 3], label="-", buttoncolor=:red, tellwidth=false)

    btn_grid = GridLayout(tellwidth=false, halign=:left)
    grid[1, 2] = btn_grid

    # colsize!(btn_grid, 1, Auto())
    # colsize!(btn_grid, 2, Auto())

    bAdd    = Button(btn_grid[1, 1], label = "+", labelcolor=:white, font=:bold, buttoncolor = RGBAf(0,1,0, 0.5))
    bRemove = Button(btn_grid[1, 2], label = "-", labelcolor=:white, font=:bold, buttoncolor = RGBAf(1,0,0, 0.8))

    on(bAdd.clicks) do click 
        push!(bodies[], PhysicsBody(@SVector[0f0, 0f0, 0f0], @SVector[0f0,0f0,0f0], 1f0))
        notify(bodies)
    end
    on(bRemove.clicks) do click 
        isempty(bodies[]) && return nothing
        isnothing(menu.selection[]) && return nothing

        deleteat!(bodies[], selected_index[])
        notify(bodies)
    end

    # When menu changes, update our index
    on(menu.selection) do selection
        isnothing(selection) && return nothing

        idx = parse(Int, selection)
        selected_index[] = idx
    end

    Box(grid[2, 1:2], color = :gray) 
    inspector_grid = GridLayout(grid[2, 1:2], tellwidth=false)

    bodyInspector(menu, inspector_grid, bodies, selected_index)

    toggle_wireframe = Toggle(grid[3,1], active=true, halign=:right, tellwidth=false)
    Label(grid[3,2], "Show Gravitational Potential", halign=:left, tellwidth=false)

    sl_wireframe = Slider(grid[4,1], range=0.01:0.01:0.1, startvalue=0.5, snap=true, width=100, halign=:right, tellwidth=false)
    Label(grid[4,2], "Wireframe scale", halign=:left, tellwidth=false)

    return UIElements(toggle_wireframe, sl_wireframe)
end

function bodyRenderer(fig::Figure, ax::LScene, bodies::Observable, uielements::UIElements)
    pos = @lift([Point3f(body.pos) for body in $(bodies)]) 

    power::Float32 = 1/3
    sizes = @lift([body.mass^power for body in $(bodies)])

    sphere = Sphere(Point3f(0), 1f0)

    meshscatter!(
        ax,
        pos;
        marker = sphere,
        markersize = sizes,
        color = :white,
        shading = true
    )
end

function create_grid(step::Float64)
    x = collect(-2:step:2)
    y = collect(-2:step:2)
    z = zeros(Float32, length(x), length(y))
    return x,y,z
end

function wireframeRenderer(fig::Figure, ax::LScene, bodies::Observable, uielements::UIElements)
    wireframe_enabled = uielements.cb_wireframe.active
    slider = uielements.sl_wireframe.value


    grid_geom = lift(slider) do step
        x, y, z = create_grid(step)
        return (x,y,z)
    end

    x_obs = @lift($grid_geom[1])
    y_obs = @lift($grid_geom[2])

    z = lift(bodies, grid_geom, wireframe_enabled) do bodies, (x,y,zbuf), enabled
        fill!(zbuf, 0f0)
        if !enabled
            return zbuf
        end

        for b in bodies
            for j in eachindex(y), i in eachindex(x)
                dx = x[i] - b.pos[1]
                dy = y[j] - b.pos[2]
                dist2 = max(dx*dx + dy*dy, 1f-4)

                # Grav potential
                zbuf[i, j] -= b.mass / sqrt(dist2)
            end
        end
        
        zbuf *= 0.01f0
        return zbuf
    end

    wireframe!(ax, x_obs, y_obs, z, visible=wireframe_enabled)
end

end

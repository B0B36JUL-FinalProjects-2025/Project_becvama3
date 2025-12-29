module Renderer

using GLMakie

export prepare_glmakie, prepare_render

function prepare_glmakie()
    GLMakie.activate!()
    GLMakie.closeall()
end

function prepare_render(bodies::Observable)
    fig = Figure(backgroundcolor = :gray20)
    ax = LScene(fig[1, 1], show_axis=false, scenekw = (backgroundcolor = :gray20, clear=true))

    pos = @lift([Point3f(body.pos) for body in $(bodies)]) 
    sizes = @lift([body.size for body in $(bodies)])

    scatter!(ax, pos; markersize=sizes, color=:white)

    display(fig)
    return fig
end

end

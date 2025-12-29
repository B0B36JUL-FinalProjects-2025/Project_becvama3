module Renderer

using GLMakie

export prepare_glmakie, prepare_render

function prepare_glmakie()
    GLMakie.activate!()
    GLMakie.closeall()
end

function prepare_render(points::Observable)
    fig = Figure()
    ax = LScene(fig[1, 1], show_axis=false, scenekw = (backgroundcolor = :white, clear=true))

    scatter!(ax, points; markersize=10)

    display(fig)
    return fig
end

end

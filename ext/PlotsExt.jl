module PlotsExt
import JolinPluto, Plots

#=
julia -e 'if isfile(joinpath(ARGS[1], "CondaPkg.toml"))
import Pkg
Pkg.add("CondaPkg")
import CondaPkg  # needed for JolinPlutoCICD.resolve_condapkg
import JolinPlutoCICD
JolinPlutoCICD.resolve_condapkg(ARGS[1])
end' "$GITHUB_WORKSPACE/$notebook_env"
=#

# little helper to support plotly responsiveness
# see this issue for updates https://github.com/JuliaPlots/Plots.jl/issues/4775
function JolinPluto.plotly_responsive(plt=Plots.current())
	HTML("<div>" * replace(
		Plots.embeddable_html(plt),
		# adapt margin as it interfers with responsive
		r"\"margin\": \{[^\}]*\},"s => """
			"margin": {"l": 40,"b": 40,"r": 0,"t": 22},""",
		# delete extra outer style attribute - not needed at all
		r"style=\"[^\"]*\""s => "",
		# delete layout width as this interfers with responsiveness
		r"\"width\":[^,}]*"s => "",
		# add extra config json at the end of the call to Plotly.newPlot
		");" => ", {\"responsive\": true});"
	) * "</div>")
end

end

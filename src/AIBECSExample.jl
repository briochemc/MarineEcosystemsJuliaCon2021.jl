### A Pluto.jl notebook ###
# v0.19.19

using Markdown
using InteractiveUtils

# This Pluto notebook uses @bind for interactivity. When running this notebook outside of Pluto, the following 'mock version' of @bind gives bound variables a default value (instead of an error).
macro bind(def, element)
    quote
        local iv = try Base.loaded_modules[Base.PkgId(Base.UUID("6e696c72-6542-2067-7265-42206c756150"), "AbstractPlutoDingetjes")].Bonds.initial_value catch; b -> missing; end
        local el = $(esc(element))
        global $(esc(def)) = Core.applicable(Base.get, el) ? Base.get(el) : iv(el)
        el
    end
end

# ╔═╡ 0a889312-d965-11eb-28e0-a72a1379850a
using AIBECS

# ╔═╡ dd802a34-6bf2-4395-95e6-1cacf33834c8
using Unitful: m, s, yr, nM

# ╔═╡ 4d57848c-a2e7-4d5a-b848-f3822437da6a
using Plots

# ╔═╡ 361bbe46-bf9a-4a6c-834f-5a0660f9a0e6
using OceanBasins

# ╔═╡ 325084cb-b233-4a63-8f8c-7ba32b7e8d43
using PlutoUI

# ╔═╡ b0dd2638-2e67-4f29-899a-4dba8d25c960
md"""
# [AIBECS.jl](https://github.com/JuliaOcean/AIBECS.jl) tutorial: Radiocarbon age

In this notebook, you will simulate the radiocarbon age in the global ocean in just a few minutes!
"""

# ╔═╡ a1638e89-30b4-41e6-ae6c-9b0cd0c92fcd
md"""
!!! note
    This notebook is heavily inspired from [the radiocarbon tutorial in AIBECS.jl's documentation](https://juliaocean.github.io/AIBECS.jl/stable/tutorials/2_radiocarbon/).
"""

# ╔═╡ 604a6a0b-0fc4-47e4-9dc1-dbb56106852b
md"""
!!! warning
    On your first run, the installation of the packages, their precompilation, and the download of the data should take a few minutes. You can expect up to 10-minutes wait on a slow laptop with a slow internet connection... **Please be patient!**
"""

# ╔═╡ 41e825fa-43e2-4b33-9e25-98145cb4eb63
md"""
## Introduction

Radiocarbon, ¹⁴C, is produced by cosmic rays hitting ¹⁴N atoms in the lower stratosphere and upper troposphere.
¹⁴C then quickly reacts with oxygen to produce ¹⁴CO₂, which eventually enters the ocean through air–sea gas exchange.

As it travels the oceans, radiocarbon decays (halflife ~5730 yr).
Deviations of ¹⁴C concentrations away from atmoshperic values serve as a tracer label for the time passed since a water parcel was last in contact with the atmosphere.

We call this mean time the "radiocarbon age", and we are going to calculate it!

![](https://user-images.githubusercontent.com/4486578/211448037-f4936ebf-a98b-4d2d-aea7-212083f30dbe.png)
*image retrieved 26 May 202 from [a "Past Oceans and Climate" blog post by Luke Skinner](https://wserv4.esc.cam.ac.uk/pastclimate/?page_id=19) (the URL may not be valid anymore)*
"""

# ╔═╡ 1d84e220-7bca-489b-83d8-87fe26398435
md"""
!!! tip "Tip: It's a clickable plot!"
	You can click on the plot above to select a (lat/lon) location!"
"""

# ╔═╡ 1d5df523-879e-4398-849e-d4b21003dd12
html"""
<h2>Tracer equation</h2>
"""

# ╔═╡ 2b531ea8-87eb-4a63-aabc-e7520f18a893
md"""
#### Continuous PDE

The "real" three-dimensional PDE for $R(x,y,z)$ is

$$\frac{\partial R}{\partial t} + \underbrace{\nabla \cdot \left[ \boldsymbol{u} - \mathbf{K} \cdot \nabla \right] R}_\mathsf{circulation} = \underbrace{ \frac{\lambda}{h} (R_\mathsf{atm} - R) (z ≤ h)}_\mathsf{air–sea~exchange} - \underbrace{R / \tau}_\mathsf{decay},$$

where $\frac{\partial R}{\partial t}$ is the rate of change of $R$ and $\nabla \cdot \left[ \boldsymbol{u} - \mathbf{K} \cdot \nabla \right] R$ is the flux divergence of $R$ due to the ocean circulation, here given by the mean advective currents $\boldsymbol{u}$ and an eddy-diffusivity matrix $\mathbf{K}$. The first term on the right-hand-side represents the air–sea gas exchange with a piston velocity $λ$ over a depth $h$ and $R / \tau$ is the radioactive decay rate, where $\tau$ is the radioactive decay timescale.

In this notebook, the goal is to solve for the steady-state of the tracer equation.
"""

# ╔═╡ 59304232-cf0f-47ec-b993-86afcd2cc227
html"""

<h4> Discretize and linearize the PDE</h4>

<p>For any model of ocean or atmospheric processes, we must discretize the equation onto a 3D grid. Below is an example of a very coarse ocean circulation model, with just 5 boxes for water"</p>

<img src="https://user-images.githubusercontent.com/4486578/58314610-3b130b80-7e53-11e9-9fe8-9527cdcca2d0.png" width=80%><br>

<em>image from François Primeau and Louis Primeau</em>
"""

# ╔═╡ 5473f343-4dd5-4aef-88c9-4287a876d7f9
html"""

<img src="https://user-images.githubusercontent.com/4486578/61757212-fe3ba480-ae02-11e9-8d17-d72866eaafb5.gif" width=60% align="right">
<p>With AIBECS, the 3D field is rearranged into a column vector. Taking the toy model of ocean circulation above, this means that the 5 boxes are stacked together to form a 5-element column, like illustrated on the right.</p>

<p>The tracer equation given after discretization and reorganization into column vectors, is the "discrete" tracer equation. It is given by</p>
"""

# ╔═╡ fc00184b-9bcc-4833-9fc8-49ef2efbd3af
md"""
#### Discrete tracer equation

The tracer equation we solve the steady-state of is

$$\frac{\partial \boldsymbol{R}}{\partial t} + \mathbf{T} \, \boldsymbol{R} = \frac{\lambda}{h} (R_\mathsf{atm} - \boldsymbol{R}) (\boldsymbol{z} ≤ h) - \boldsymbol{R} / \tau.$$

where now $\boldsymbol{R}$ is a column vector of radiocarbon concentrations and $\mathbf{T}$ is a sparse matrix representing the ocean circulation.

**The goal is to solve for the steady state, i.e.,**

$$\frac{\partial \boldsymbol{R}}{\partial t} = 0.$$
"""

# ╔═╡ ba54f82c-9e6c-409d-86bd-a85cc4609357
md"""
## Simulate radiocarbon age
"""

# ╔═╡ 38129859-df5e-4faa-a75c-8304b2bed55b
md"""
### 1. Load AIBECS
"""

# ╔═╡ 56bf3614-092d-4891-b1aa-7b2c5e1ddcbc
md"""
### 2. Chose a circulation model
"""

# ╔═╡ 4bbffe2c-0520-4e7b-bf38-0857454336ef
md"""
Load the circulation grid and matrix. Here I chose the `OCCA` matrix, which was built using the MIT general circulation model, but you can select other circulations, like the `OCIM2` one, for example (FYI, the OCCA matrix was made by Gael Forget, the organizer of this workshop).
"""

# ╔═╡ 35641e0f-537c-476a-86bd-d690d0989736
grd, T = OCCA.load() ;

# ╔═╡ cb8c4c09-6783-42c1-b114-d2a20dbfa3f7
md"""
!!! warning
    This cell downloads some data on the first run, so it may take a little time. It is also possible that it stumbles and errors. If it happens, just try to run it again!
"""

# ╔═╡ bcc5fa0f-7595-4a21-a057-1cbabf94a049
md"""
!!! tip "Tip: You can swap circulations!"
	For example, you can use the Ocean Circulation Inverse Model (OCIM) matrices using 
	```julia
	grd, T = OCIM2.load() ;
	```

	These OCIM2 matrices come in different flavors, whcih you can select with the `version` keyword argument, e.g., with
    ```julia
	OCIM2.load(version="KiHIGH_He")
	```
	for increased isopycnal diffusivity, or use `version="KvHIGH_He"` for increased vertical diffusivity.
"""

# ╔═╡ d76ec9fb-77f4-4a14-afb2-713cbd03ffab
md"""
The grid, `grd`, contains a bunch of properties, like latitude, longitude, depth, and so on.
"""

# ╔═╡ ba5fb3fa-b9f8-43c3-881c-0dc26c399b70
fieldnames(typeof(grd))

# ╔═╡ 5862c0fe-ff2c-45c9-aef4-ab0635442ee5
md"""
And `T` is the sparse matrix of the ocean circulation.
"""

# ╔═╡ ac71b40d-5f79-4881-9086-c71c89077499
T

# ╔═╡ fe54d279-6d03-4892-9c0f-9dccb42b77a1
md"""
### 3. Local sources and sinks

We lump the local sources and sinks (air–sea exchange and decay) into a `RHS` function.
"""

# ╔═╡ 3c300825-ef08-4e5d-ab29-9264bb8e1024
md"""
Above you'll note that I "unpack" a bunch of scalar parameters. We'll deal with those in the next section. But first, let us define `z`, the column vector of all the depths of all the boxes, for which there is the `depthvec` function.
"""

# ╔═╡ 5b99fcb5-c3e1-4a01-84e6-334b26562301
z = depthvec(grd)

# ╔═╡ daef9e51-08b5-4ab3-946a-703052ef1a34
function RHS(R,p)
    @unpack λ, h, Ratm, τ = p
    return @. λ / h * (Ratm - R) * (z ≤ h) - R / τ
end

# ╔═╡ c9f07270-f1ce-4b1b-b8b0-a4ab53440366
md"""
### 4. Parameters

We define our variable parameters (those that I unpacked earlier) with a special `struct`. Here we do that with a little add-on package for units. But to do that we must first import some unit functions
"""

# ╔═╡ 7679b0ba-5a04-4af3-9f58-80644da08f9e
md"""
Now we define our parameter structure called `Params`.
"""

# ╔═╡ 202247cd-7a29-4f24-a5f9-831badce334f
struct Params{U} <: AbstractParameters{U}
	λ::U
	h::U
	τ::U
	Ratm::U
end

# ╔═╡ 55292329-200f-4cf3-bb1d-e4cff6def15b
md"""
For the air–sea gas exchange, we use a constant piston velocity $\lambda$ of 50m / 10years.
And for the radioactive decay we use a timescale $\tau$ of 5730/log(2) years.
"""

# ╔═╡ e533c789-73e5-4843-b58e-9b00c950aa0b
p = Params(λ    = 50.0m/10yr    |> upreferred |> ustrip,
           h    = grd.δdepth[1] |> upreferred |> ustrip,
           τ    = 5730yr/log(2) |> upreferred |> ustrip,
           Ratm = 42.0nM        |> upreferred |> ustrip)

# ╔═╡ d4c9bb7f-7e92-4b42-af59-d74d7db3298c
md"""
!!! note "Note on units"
	You can specify different units and AIBECS (thanks to [Unitful.jl](https://github.com/PainterQubits/Unitful.jl)), will do the conversions for you.
	However, this relies on machinery that is not compatible with Pluto notebooks ([more details here](https://github.com/openjournals/joss-reviews/issues/3814#issuecomment-990636119)), so here we strip the units (with `|> upreferred |> ustrip`).
"""

# ╔═╡ fa2265a6-3bf5-4b29-9fcb-271d1215ea62
md"""
### 5. The "state" function and its Jacobian

To simulate radiocarbon, AIBECS first collects all the terms of the rate of change into a big "state" function that depends on the state (here just the radiocarbon concentration vector $\boldsymbol{R}$ and the parameters $\boldsymbol{p}$),

$$\boldsymbol{F}(\boldsymbol{R}, \boldsymbol{p}) = \frac{\partial \boldsymbol{R}}{\partial t}$$

and then AIBECS solves for the steady-state by looking for roots of $\boldsymbol{F}$, i.e., the $\boldsymbol{R}$ values such that 

$$\boldsymbol{F}(\boldsymbol{R}, \boldsymbol{p}) = 0$$

To find that root, AIBECS uses a quasi-Newton solver, which requires the Jacobian of $\boldsymbol{F}$ w.r.t. $\boldsymbol{R}$, which we denote by $\nabla_\boldsymbol{x}\boldsymbol{F}$, which is a sparse matrix just like $\mathbf{T}$. But don't worry, AIBECS can compute both of them for you using the `F_and_∇ₓF` function.
"""

# ╔═╡ 9a40e63d-bcb0-47d9-9daa-f98e6b2d90d7
F = AIBECSFunction(T, RHS)

# ╔═╡ 4e82b6b7-abb8-4248-ad92-65e082c2eedc
md"""
### 6. Run the simulation!

We chose an initial guess for the values of $\boldsymbol{R}$ (here just zeros).
"""

# ╔═╡ 8875b4e6-95ca-4c31-a6c5-70fd7193f5a5
R₀ = zeros(length(z)) # an initial guess

# ╔═╡ 77d30cef-dc91-4db1-886f-15b4787f1ec7
md"""
We generate the steady-state problem (following SciML lingo)"""

# ╔═╡ fa03c28c-5c2a-4764-9260-6acd9b5ec5a3
prob = SteadyStateProblem(F, R₀, p) ;

# ╔═╡ da45685f-db9b-4c8a-a62b-0bc9cfc04311
md"""And we solve it."""

# ╔═╡ d3074335-0625-402a-b4d3-6ae65c8cd168
R = solve(prob, CTKAlg()).u # in SciML lingo, the solution array is in `.u`

# ╔═╡ 4530a0c3-c05a-46ab-9510-aeac2d56da1a
md"""
!!! note
	Right now, the `CTKAlg()` solver is housed inside of AIBECS. Eventually however (and hopefully), AIBECS will rely on SciML's [NonlinearSolve.jl](https://github.com/SciML/NonlinearSolve.jl) to provide the many available solvers in Julia.
"""

# ╔═╡ 8a231ad0-e2a9-423a-b1b0-e600e0e3aac2
md"""
Since radiocarbon decays with timescale $\tau$, if $t$ is the radiocarbon age as we follow a water parcel, then

$$R = R_\mathsf{atm} \exp(-t/\tau)$$

Thus, we recover the radiocarbon age $t$ via

$$t = \tau \log(R_\mathsf{atm} / R)$$
"""

# ╔═╡ 59dd2d1e-78e2-431d-ad92-a7368b8e54ce
C14age = let
	@unpack τ, Ratm = p
	@. τ * log(Ratm / R) * s |> yr
end

# ╔═╡ fdc77b5c-5a56-43bc-b304-89f1f064c9a5
md"""
That's it, now let's plot this radiocarbon age!
"""

# ╔═╡ 5d8b2518-66a5-4ab2-992b-b80b98d1a498
md"""
### Plot it from all angles
"""

# ╔═╡ d9114195-74b2-4c2d-bc0a-151fa37bc46a
md"""
AIBECS comes with some plotting recipes for [Plots.jl](https://github.com/JuliaPlots/Plots.jl), so let's use it!
"""

# ╔═╡ 67ce45d2-96e7-470b-8f36-b062b5a51d7d
md"""
### Horizontal slice
"""

# ╔═╡ c9ed1499-4bc6-45d6-921f-9e023fe28736
md"""
One recipe, for example, is `plothorizontalslice`. Here is an example:
"""

# ╔═╡ c0c6a6b9-407d-4861-bb27-6e150ee3381d
md"""
!!! tip "Tip: These are reactive plots!"
	You can select the depth (see the slider), move it around to see maps at different depths. 
"""

# ╔═╡ a508b27d-4a2d-4453-87e8-c6d330f65b6d
md"""
You can customize your plots to look better by combining recipes and attributes. For example, I like to see contour lines. That's what the function below does
"""

# ╔═╡ b4ac7dc7-6000-40c0-a081-c39bc3d286d9
md"""
So that the horizontal slice looks better!
"""

# ╔═╡ e648c42a-9ebc-46f0-bdff-55d74a284009
md"""
### Meridional slice
"""

# ╔═╡ 2d338a77-33ee-4256-a728-fafb7d15c13a
md"""
There's also a recipe for meridional slices. Like above, we can customize it to get a pretty plot:
"""

# ╔═╡ eddb1866-9242-485a-9971-a0b1043d0eb7
md"""
!!! tip "Tip: Take a different slice!"
	You can move the cell of the first plot (with the lat/lon selector) and pick a different location (through which the slice above is taken)!
"""

# ╔═╡ d444fc11-9113-41bb-86a8-792feabafe7f
md"""
### Tracer vs depth profile
"""

# ╔═╡ 2dabc2fc-45f6-4454-855d-555f3eacefdf
md"""
!!! tip "Tip: Chose your best profile!"
	Select the profile location with the (lat/lon)-selector plot...
"""

# ╔═╡ 488c6914-0a09-475f-870b-6148dc6dadb3
md"""
### Zonal average
"""

# ╔═╡ 0268bff0-7ccd-404f-8424-78444885fb4a
md"""
We can take a zonal average as well (using the `plotzonalaverage` function)
"""

# ╔═╡ c9cb1b8e-bb4a-4f74-9e35-96ad9530413e
md"""
### Global mean profile
"""

# ╔═╡ 9a95c55a-8e44-42d3-a52e-2f18d670811b
md"""
Or a mean profile
"""

# ╔═╡ a6407c69-ac39-4819-9429-239f43a5dc63
md"""
That should be the end of the tutorial presentation. 
Below is a tiny little extra example of more customization.
"""

# ╔═╡ 56a1aa18-0134-4e4f-a6cc-3662316284dc
md"""
## Extras for the breakout session! 

### Compose with other packages
"""

# ╔═╡ 3db99f8c-f238-427c-8239-19a7d94401b7
md"""
As an example, let's load the polygons of the 3 major basins and look at plots restriced to these areas
"""

# ╔═╡ e0267345-df37-410b-bcca-218e35388f87
OCEANS = oceanpolygons()

# ╔═╡ 17c15ad0-c7b9-4a6e-9375-4bcc1f84a517
md"""
!!! warning
    This cell downloads some data (ocean polygons) on the first run, so it may take a little time. It is also possible that it stumbles and errors. If it happens, just try to run it again!
"""

# ╔═╡ 246063c6-d2ca-4796-88c5-fa1489e6381b
masks = (
	ATL = isatlantic(latvec(grd), lonvec(grd), OCEANS),
	PAC = ispacific(latvec(grd), lonvec(grd), OCEANS),
	IND = isindian(latvec(grd), lonvec(grd), OCEANS),
)

# ╔═╡ f7ad9931-1d92-4d08-a0ee-9393dd524f92
md"""
## Extra settings

Below are cells that are not necessarily needed for this notebook but they facilitate some things.
"""

# ╔═╡ 25f7c2a3-a8a7-441e-8da1-b311fd355867
md"""

##### Always accept downloads

The AIBECS.jl package provides functions to download different ocean circulations using the DataDeps.jl package, which ususally requires the user to accept each download individually. The cell below tells DataDeps.jl to always accept downloads, so that this notebook can be self-contained and fetch the circulation you want automatically.
"""

# ╔═╡ c08308c9-eade-4209-b755-2415542e542a
ENV["DATADEPS_ALWAYS_ACCEPT"] = true

# ╔═╡ cffb9e34-c2ab-40c2-8006-e1fd934fd066
md"""
##### Plot options
"""

# ╔═╡ d5a447b4-2d22-4466-b89f-de859ed9f09e
clim=(0,2500)

# ╔═╡ 22a18398-a6ac-4229-8a52-e984315bb699
cmap = cgrad(:davos, rev=true)

# ╔═╡ c91b9d30-b8e0-457a-a958-2d5f60451b78
basin_colors = cgrad(:tableau_colorblind, categorical=true)[[4, 5, 2, 3]]

# ╔═╡ e14f6526-c5e3-4c17-896e-2983c030f5e9
begin
	plotverticalmean(sum(k*mask for (k,mask) in enumerate(masks)), grd; title="Ocean basins", color=cgrad(basin_colors, categorical=true), clim=(-0.5,length(masks)+0.5), colorbar=false)
	annotate!(80, -15, "IND")
	annotate!(200, 0, "PAC")
	annotate!(315, 30, "ATL")
end

# ╔═╡ 9f2ece88-dbc7-495e-9ca5-6518af58caf8
# repeated plot options are colorbartitle, colormap, extra margin for colorbar title
plot_options = (;
	colorbartitle="\nage",  # The new line moves cbar label to avoid overlap but...
	right_margin=3Plots.mm, # but the moved cbar label needs more space!
	color=cmap, 
	clim)

# ╔═╡ d4521113-4a5c-4154-877f-7228885e0ac2
function myhorizontalslice(x, grd; depth, kwargs...)
	# Default heatmap
	plothorizontalslice(x, grd; depth, plot_options..., kwargs...)
	# Overlay filled contour (you can comment this one out for example)
	plothorizontalslice!(x, grd; depth, plot_options..., levs=0:100:2500, st=:contourf, lw=0)
	# and some black contours (for looks)
	plothorizontalslice!(x, grd; depth, plot_options..., levs=0:500:2500, st=:contour, c=:black, clabels=true)
end

# ╔═╡ 75b087ff-fb90-4a79-b95b-678157f4046e
function myzonalaverage(x, grd; kwargs...)
	p = plotzonalaverage(x, grd; plot_options..., yunit=u"km", kwargs...)
	#plotzonalaverage!(p, x, grd; plot_options..., yunit=u"km", st=:contourf, levs=0:100:2500, lw=0, clabels=true, kwargs...)
	plotzonalaverage!(p, x, grd; plot_options..., yunit=u"km", st=:contour, levs=0:500:2500, c=:black, clabels=true, kwargs...)
	p
end

# ╔═╡ f0d1a772-2b1d-4feb-8d52-b9dbf29b3f45
myzonalaverage(C14age, grd; title="Global zonal average of radiocarbon age")

# ╔═╡ 8f76c559-ef89-46c0-a792-75a1de96f6e5
plot([myzonalaverage(C14age, grd; mask, title="Zonal average ($m)") 
		for (m,mask) in pairs(masks)]..., layout=(length(masks),1), size=(500,800))

# ╔═╡ ee1d8881-4dce-45d3-95fa-9bb33819ebe9
plothorizontalaverage(C14age, grd; plot_options..., c=1, xlim=clim, lab="", xlab="Horizontally averaged radiocarbon age", lw=3)

# ╔═╡ 98508321-fb4b-4076-9c95-0d38f63303b8
let
	p = plot(xlim=clim, xlab="Basin averaged radiocarbon age", legend=:bottomleft)
	for (icolor, (m,mask)) in enumerate(pairs(masks))
		plothorizontalaverage!(p, C14age, grd; mask, 
			plot_options..., 
			c=basin_colors[icolor+1], 
			lw=3, 
			lab="$m", 
		)
	end
	p
end

# ╔═╡ cc9fb021-35f9-4183-b992-40d82a5c1d2b
md"""
## User interface
"""

# ╔═╡ b505808f-6a05-4f2a-b755-201065b9c5f5
function plotclicktracker(p::Plots.Plot; draggable::Bool=false)

	# we need to render the plot before its dimensions are available:
	# plot_render = repr(MIME"image/svg+xml"(),  p)
	plot_render = repr(MIME"image/svg+xml"(),  p)

	# these are the _bounding boxes_ of our plot
	big = bbox(p.layout)
	small = plotarea(p[1])

	# the axis limits
	xl = xlims(p)
	yl = ylims(p)

	# with this information, we can form the linear transformation from 
	# screen coordinate -> plot coordinate

	# this is done on the JS side, to avoid one step in the Julia side
	# we send the linear coefficients:
	r = (
	x_offset = xl[1] - (xl[2] - xl[1]) * small.x0[1] / small.a[1],
	x_scale = (big.a[1] / small.a[1]) * (xl[2] - xl[1]),
	y_offset = (yl[2] - yl[1]) + (small.x0[2] / small.a[2]) * (yl[2] - yl[1]) + yl[1],
	y_scale = -(big.a[2]/ small.a[2]) * (yl[2] - yl[1]),
	x_min = xl[1], # TODO: add margin
	x_max = xl[2],
	y_min = yl[1],
	y_max = yl[2],
	)

	HTML("""<script id="hello">
		const body = $(PlutoRunner.publish_to_js(plot_render))
		const mime = "image/svg+xml"
		const img = this ?? document.createElement("img")
		let url = URL.createObjectURL(new Blob([body], { type: mime }))
		img.type = mime
		img.src = url
		img.draggable = false
		
		const clamp = (x,a,b) => Math.min(Math.max(x, a), b)
		img.transform = f => [
			clamp(f[0] * $(r.x_scale) + $(r.x_offset), $(r.x_min), $(r.x_max)),
			clamp(f[1] * $(r.y_scale) + $(r.y_offset), $(r.y_min), $(r.y_max)),
		]
		img.fired = false
		
		const val = {current: undefined }
		
		if(this == null) {
		Object.defineProperty(img, "value", {
			get: () => val.current,
			set: () => {},
		})
		
		const handle_mouse = (e) => {
			const svgrect = img.getBoundingClientRect()
			const f = [
				(e.clientX - svgrect.left) / svgrect.width, 
				(e.clientY - svgrect.top) / svgrect.height
			]
		console.log(f)
			if(img.fired === false){
				img.fired = true
				val.current = img.transform(f)
				img.dispatchEvent(new CustomEvent("input"), {})
			}
		}
		img.addEventListener("click", onclick)
		img.addEventListener("pointerdown", e => {
			if($(draggable)){
				img.addEventListener("pointermove", handle_mouse);
			}
			handle_mouse(e);
		});
		const mouseup = e => {
			console.log(e)
			img.removeEventListener("pointermove", handle_mouse);
		};
		document.addEventListener("pointerup", mouseup);
		document.addEventListener("pointerleave", mouseup);
		}
		return img
		</script>""")
end

# ╔═╡ 7a209d2b-06b8-4177-a728-14a6b7e364ed
begin
	default_usage_error = :(error("Example usage:\n\n@intially [1,2] @bind x f(x)\n"))
	
	macro initially(::Any)
		default_usage_error
	end
	
	macro initially(default, bind_expr::Expr)
		if bind_expr.head != :macrocall || bind_expr.args[1] != Symbol("@bind")
			return default_usage_error
		end
		
		# warn if the first argument is a @bind
		if default isa Expr && default.head == :macrocall && default.args[1] == Symbol("@bind")
			return default_usage_error
		end
			
		esc(intially_function(default, bind_expr))
	end
	
	
	function intially_function(default, bind_expr)
		sym = bind_expr.args[3]
		@gensym setval bond

		quote
			if !@isdefined($sym)
				$sym = $default
			end

			$setval = $sym


			$bond = @bind $sym $(bind_expr.args[4])
			PlutoRunner.Bond

			if $sym isa Missing
				$sym = $setval
			end

			$bond
		end
	end
end

# ╔═╡ bd6d5348-56e9-45d0-8770-0499d437b0a6
depth_slider = @bind depth Slider(0:50:6000, show_value=true, default=500)

# ╔═╡ d2a72eda-685e-4033-acc4-d384f2816e80
md"""
depth = $(depth_slider)
"""

# ╔═╡ be2300ea-50a6-42b3-bc3b-3e65e01b3203
plothorizontalslice(C14age, grd; depth)

# ╔═╡ 1d63cee3-0d5d-497d-b019-ce9c8865c4d4
md"""
depth = $(depth_slider)
"""

# ╔═╡ 25379449-9118-4d18-8688-1bedccd454b9
myhorizontalslice(C14age, grd; depth, title="Radiocarbon age at $(depth)m")

# ╔═╡ 2dbc5948-3c9e-4a93-9919-702fab2a992d
function prettylon(lon)
	lon = round(Int, mod(lon + 180, 360) - 180)
	lon == 0 ? "0°" : lon > 0 ? "$(lon)°E" : "$(-lon)°W"
end

# ╔═╡ 1a9b44b4-415f-47aa-acae-dbef7c9af54a
function prettylat(lat)
	lat = round(Int, lat)
	lat == 0 ? "Eq" : lat > 0 ? "$(lat)°N" : "$(-lat)°S"
end

# ╔═╡ dd59eee8-2265-4487-a875-a09aca2d9cb0
function slice_and_profile(click_coordinate)
	p = plothorizontalslice(C14age, grd; depth, title="Radiocarbon age at $(depth)m", color=cmap, clim, colorbar=false)
	plothorizontalslice!(p, C14age, grd; depth, seriestype=:contourf, levels=0:125:2500, clim, color=cmap, lw=0)
	plothorizontalslice!(p, C14age, grd; depth, seriestype=:contour, levels=0:250:5000, color=:black, contour_labels=true)
	# profile
	if !isnothing(click_coordinate)
		lon, lat = click_coordinate
		lon2, lat2 = prettylon(lon), prettylat(lat)
		scatter!(p, [lon], [lat], c=:black, lab="")
		annotate!(lon, lat-10, text("$(lon2), $(lat2)", 10, :red))
		vline!(p, [lon], lab="", c=:red, linestyle=:dash)
		hline!(p, [lat], lab="", c=:red, linestyle=:dash)
		# profile
		pro = plotdepthprofile(C14age, grd; lonlat=(lon,lat), xlim=(0,3000), yunit=u"km", lab="", xlab="Age", lw=3)
		hline!(pro, [depth * u"m"], lab="", c=:red, linestyle=:dash)
	else
		pro = plothorizontalaverage(C14age, grd, xlim=(0,3000), yunit=u"km", lab="", xlab="Age")
	end
	xlims!(p, (0,360))
	ylims!(p, (-90,90))
	# home-made colorbar
	crange = range(clim..., length=100)
	cbar = contourf(crange * u"yr", [0,1], [crange crange]'; color=cmap, levels=0:125:2500, clim, colorbar=false, yticks=[], xlab="Radiocarbon age", lw=0)
	contour!(cbar, crange * u"yr", [0,1], [crange crange]'; color=:black, levels=0:250:5000) 
	# combine plots
	p1 = plot(p, cbar, layout=grid(2, 1, heights=(0.925, 0.075)))
	plot(p1, pro, layout=grid(1, 2, widths=(0.8, 0.2)), size=(800,400), bottom_margin=3Plots.mm)
end

# ╔═╡ d8ac806d-99b8-4a69-a31d-a92711b274af
mainplot = @initially [160.0,0.0] @bind x0 plotclicktracker(slice_and_profile(x0); draggable=true)

# ╔═╡ e552da86-a408-4b3f-a0b6-eb9e9702ddc5
lon, lat = isnothing(x0) ? (180, 0) : x0 # a tuple of longitude and latitude sliders

# ╔═╡ ebce3a87-1fd8-4f63-a7ac-c97476c15323
let
	p = plotmeridionalslice(C14age, grd; lon, title="Radiocarbon age at $(prettylon(lon))", plot_options...)
	# Overlay black contours (nicer on the eyes)
	plotmeridionalslice!(C14age, grd; lon, st=:contour, levs=0:250:3000, clabels=true, c=:black, plot_options...)
	# Overlay red lines for latitude of target latitude and depth
	#hline!([depth], lab="", c=:red, linestyle=:dash)
	#vline!([lat], lab="", c=:red, linestyle=:dash)
end

# ╔═╡ 66364ec2-d852-4d02-940f-feafd7deb53d
plotdepthprofile(C14age, grd; lonlat=(lon,lat), 
	title="Radiocarbon age at ($(prettylon(lon)), $(prettylat(lat)))", 
	c=1, 
	lw=3,
	xlim=clim, 
	plot_options..., 
	lab=""
)

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
AIBECS = "ace601d6-714c-11e9-04e5-89b7fad23838"
OceanBasins = "d1bb7020-b2be-4340-9d18-d24ca645bddb"
Plots = "91a5bcdd-55d7-5caf-9e0b-520d859cae80"
PlutoUI = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
Unitful = "1986cc42-f94f-5a68-af5c-568840ba703d"

[compat]
AIBECS = "~0.13.2"
OceanBasins = "~0.1.7"
Plots = "~1.38.1"
PlutoUI = "~0.7.49"
Unitful = "~1.12.2"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

[[AIBECS]]
deps = ["Bijectors", "CodecZlib", "DataDeps", "DataFrames", "Dates", "Distances", "Distributions", "Downloads", "FieldMetadata", "Flatten", "ForwardDiff", "ImageFiltering", "Interpolations", "JLD2", "LinearAlgebra", "MAT", "MetadataArrays", "NCDatasets", "NearestNeighbors", "OceanGrids", "Printf", "RecipesBase", "Reexport", "SciMLBase", "Shapefile", "SparseArrays", "StringDistances", "SuiteSparse", "UnPack", "Unitful"]
git-tree-sha1 = "024d36a31fae0d0158fb0dd0cd2307dfa5762f8e"
uuid = "ace601d6-714c-11e9-04e5-89b7fad23838"
version = "0.13.2"

[[AbstractFFTs]]
deps = ["ChainRulesCore", "LinearAlgebra"]
git-tree-sha1 = "69f7020bd72f069c219b5e8c236c1fa90d2cb409"
uuid = "621f4979-c628-5d54-868e-fcf4e3e8185c"
version = "1.2.1"

[[AbstractPlutoDingetjes]]
deps = ["Pkg"]
git-tree-sha1 = "8eaf9f1b4921132a4cff3f36a1d9ba923b14a481"
uuid = "6e696c72-6542-2067-7265-42206c756150"
version = "1.1.4"

[[Adapt]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "195c5505521008abea5aee4f96930717958eac6f"
uuid = "79e6a3ab-5dfb-504d-930d-738a2a938a0e"
version = "3.4.0"

[[ArgCheck]]
git-tree-sha1 = "a3a402a35a2f7e0b87828ccabbd5ebfbebe356b4"
uuid = "dce04be8-c92d-5529-be00-80e4d2c0e197"
version = "2.3.0"

[[ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"
version = "1.1.1"

[[ArrayInterface]]
deps = ["ArrayInterfaceCore", "Compat", "IfElse", "LinearAlgebra", "Static"]
git-tree-sha1 = "6d0918cb9c0d3db7fe56bea2bc8638fc4014ac35"
uuid = "4fba245c-0d91-5ea0-9b3e-6abc04ee57a9"
version = "6.0.24"

[[ArrayInterfaceCore]]
deps = ["LinearAlgebra", "SparseArrays", "SuiteSparse"]
git-tree-sha1 = "14c3f84a763848906ac681f94cf469a851601d92"
uuid = "30b0a656-2188-435a-8636-2ec0e6a096e2"
version = "0.1.28"

[[ArrayInterfaceStaticArraysCore]]
deps = ["Adapt", "ArrayInterfaceCore", "LinearAlgebra", "StaticArraysCore"]
git-tree-sha1 = "93c8ba53d8d26e124a5a8d4ec914c3a16e6a0970"
uuid = "dd5226c6-a4d4-4bc7-8575-46859f9c95b9"
version = "0.1.3"

[[Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"

[[AxisAlgorithms]]
deps = ["LinearAlgebra", "Random", "SparseArrays", "WoodburyMatrices"]
git-tree-sha1 = "66771c8d21c8ff5e3a93379480a2307ac36863f7"
uuid = "13072b0f-2c55-5437-9ae7-d433b7a33950"
version = "1.0.1"

[[Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"

[[Bijectors]]
deps = ["ArgCheck", "ChainRulesCore", "ChangesOfVariables", "Compat", "Distributions", "Functors", "InverseFunctions", "IrrationalConstants", "LinearAlgebra", "LogExpFunctions", "MappedArrays", "Random", "Reexport", "Requires", "Roots", "SparseArrays", "Statistics"]
git-tree-sha1 = "a3704b8e5170f9339dff4e6cb286ad49464d3646"
uuid = "76274a88-744f-5084-9051-94815aaf08c4"
version = "0.10.6"

[[BitFlags]]
git-tree-sha1 = "43b1a4a8f797c1cddadf60499a8a077d4af2cd2d"
uuid = "d1d4a3ce-64b1-5f1a-9ba4-7e7e69966f35"
version = "0.1.7"

[[BufferedStreams]]
git-tree-sha1 = "bb065b14d7f941b8617bc323063dbe79f55d16ea"
uuid = "e1450e63-4bb3-523b-b2a4-4ffa8c0fd77d"
version = "1.1.0"

[[Bzip2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "19a35467a82e236ff51bc17a3a44b69ef35185a2"
uuid = "6e34b625-4abd-537c-b88f-471c36dfa7a0"
version = "1.0.8+0"

[[CFTime]]
deps = ["Dates", "Printf"]
git-tree-sha1 = "ed2e76c1c3c43fd9d0cb9248674620b29d71f2d1"
uuid = "179af706-886a-5703-950a-314cd64e0468"
version = "0.1.2"

[[Cairo_jll]]
deps = ["Artifacts", "Bzip2_jll", "CompilerSupportLibraries_jll", "Fontconfig_jll", "FreeType2_jll", "Glib_jll", "JLLWrappers", "LZO_jll", "Libdl", "Pixman_jll", "Pkg", "Xorg_libXext_jll", "Xorg_libXrender_jll", "Zlib_jll", "libpng_jll"]
git-tree-sha1 = "4b859a208b2397a7a623a03449e4636bdb17bcf2"
uuid = "83423d85-b0ee-5818-9007-b63ccbeb887a"
version = "1.16.1+1"

[[Calculus]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "f641eb0a4f00c343bbc32346e1217b86f3ce9dad"
uuid = "49dc2e85-a5d0-5ad3-a950-438e2897f1b9"
version = "0.5.1"

[[CatIndices]]
deps = ["CustomUnitRanges", "OffsetArrays"]
git-tree-sha1 = "a0f80a09780eed9b1d106a1bf62041c2efc995bc"
uuid = "aafaddc9-749c-510e-ac4f-586e18779b91"
version = "0.2.2"

[[ChainRulesCore]]
deps = ["Compat", "LinearAlgebra", "SparseArrays"]
git-tree-sha1 = "e7ff6cadf743c098e08fca25c91103ee4303c9bb"
uuid = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
version = "1.15.6"

[[ChangesOfVariables]]
deps = ["ChainRulesCore", "LinearAlgebra", "Test"]
git-tree-sha1 = "38f7a08f19d8810338d4f5085211c7dfa5d5bdd8"
uuid = "9e997f8a-9a97-42d5-a9f1-ce6bfc15e2c0"
version = "0.1.4"

[[CodecZlib]]
deps = ["TranscodingStreams", "Zlib_jll"]
git-tree-sha1 = "ded953804d019afa9a3f98981d99b33e3db7b6da"
uuid = "944b1d66-785c-5afd-91f1-9de20f533193"
version = "0.7.0"

[[ColorSchemes]]
deps = ["ColorTypes", "ColorVectorSpace", "Colors", "FixedPointNumbers", "Random", "SnoopPrecompile"]
git-tree-sha1 = "aa3edc8f8dea6cbfa176ee12f7c2fc82f0608ed3"
uuid = "35d6a980-a343-548e-a6ea-1d62b119f2f4"
version = "3.20.0"

[[ColorTypes]]
deps = ["FixedPointNumbers", "Random"]
git-tree-sha1 = "eb7f0f8307f71fac7c606984ea5fb2817275d6e4"
uuid = "3da002f7-5984-5a60-b8a6-cbb66c0b333f"
version = "0.11.4"

[[ColorVectorSpace]]
deps = ["ColorTypes", "FixedPointNumbers", "LinearAlgebra", "SpecialFunctions", "Statistics", "TensorCore"]
git-tree-sha1 = "600cc5508d66b78aae350f7accdb58763ac18589"
uuid = "c3611d14-8923-5661-9e6a-0046d554d3a4"
version = "0.9.10"

[[Colors]]
deps = ["ColorTypes", "FixedPointNumbers", "Reexport"]
git-tree-sha1 = "fc08e5930ee9a4e03f84bfb5211cb54e7769758a"
uuid = "5ae59095-9a9b-59fe-a467-6f913c188581"
version = "0.12.10"

[[CommonSolve]]
git-tree-sha1 = "9441451ee712d1aec22edad62db1a9af3dc8d852"
uuid = "38540f10-b2f7-11e9-35d8-d573e4eb0ff2"
version = "0.2.3"

[[CommonSubexpressions]]
deps = ["MacroTools", "Test"]
git-tree-sha1 = "7b8a93dba8af7e3b42fecabf646260105ac373f7"
uuid = "bbf7d656-a473-5ed7-a52c-81e309532950"
version = "0.3.0"

[[Compat]]
deps = ["Dates", "LinearAlgebra", "UUIDs"]
git-tree-sha1 = "00a2cccc7f098ff3b66806862d275ca3db9e6e5a"
uuid = "34da2185-b29b-5c13-b0c7-acf172513d20"
version = "4.5.0"

[[CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"
version = "1.0.1+0"

[[ComputationalResources]]
git-tree-sha1 = "52cb3ec90e8a8bea0e62e275ba577ad0f74821f7"
uuid = "ed09eef8-17a6-5b46-8889-db040fac31e3"
version = "0.3.2"

[[ConstructionBase]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "fb21ddd70a051d882a1686a5a550990bbe371a95"
uuid = "187b0558-2788-49d3-abe0-74a17ed4e7c9"
version = "1.4.1"

[[Contour]]
git-tree-sha1 = "d05d9e7b7aedff4e5b51a029dced05cfb6125781"
uuid = "d38c429a-6771-53c6-b99e-75d170b6e991"
version = "0.6.2"

[[Crayons]]
git-tree-sha1 = "249fe38abf76d48563e2f4556bebd215aa317e15"
uuid = "a8cc5b0e-0ffa-5ad4-8c14-923d3ee1735f"
version = "4.1.1"

[[CustomUnitRanges]]
git-tree-sha1 = "1a3f97f907e6dd8983b744d2642651bb162a3f7a"
uuid = "dc8bdbbb-1ca9-579f-8c36-e416f6a65cce"
version = "1.0.2"

[[DBFTables]]
deps = ["Printf", "Tables", "WeakRefStrings"]
git-tree-sha1 = "f5b78d021b90307fb7170c4b013f350e6abe8fed"
uuid = "75c7ada1-017a-5fb6-b8c7-2125ff2d6c93"
version = "1.0.0"

[[DataAPI]]
git-tree-sha1 = "e8119c1a33d267e16108be441a287a6981ba1630"
uuid = "9a962f9c-6df0-11e9-0e5d-c546b8b5ee8a"
version = "1.14.0"

[[DataDeps]]
deps = ["HTTP", "Libdl", "Reexport", "SHA", "p7zip_jll"]
git-tree-sha1 = "bc0a264d3e7b3eeb0b6fc9f6481f970697f29805"
uuid = "124859b0-ceae-595e-8997-d05f6a7a8dfe"
version = "0.7.10"

[[DataFrames]]
deps = ["Compat", "DataAPI", "Future", "InvertedIndices", "IteratorInterfaceExtensions", "LinearAlgebra", "Markdown", "Missings", "PooledArrays", "PrettyTables", "Printf", "REPL", "Random", "Reexport", "SnoopPrecompile", "SortingAlgorithms", "Statistics", "TableTraits", "Tables", "Unicode"]
git-tree-sha1 = "d4f69885afa5e6149d0cab3818491565cf41446d"
uuid = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
version = "1.4.4"

[[DataStructures]]
deps = ["Compat", "InteractiveUtils", "OrderedCollections"]
git-tree-sha1 = "d1fff3a548102f48987a52a2e0d114fa97d730f0"
uuid = "864edb3b-99cc-5e75-8d2d-829cb0a9cfe8"
version = "0.18.13"

[[DataValueInterfaces]]
git-tree-sha1 = "bfc1187b79289637fa0ef6d4436ebdfe6905cbd6"
uuid = "e2d170a0-9d28-54be-80f0-106bbe20a464"
version = "1.0.0"

[[Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"

[[DelimitedFiles]]
deps = ["Mmap"]
uuid = "8bb1440f-4735-579b-a4ab-409b98df4dab"

[[DensityInterface]]
deps = ["InverseFunctions", "Test"]
git-tree-sha1 = "80c3e8639e3353e5d2912fb3a1916b8455e2494b"
uuid = "b429d917-457f-4dbc-8f4c-0cc954292b1d"
version = "0.4.0"

[[DiffResults]]
deps = ["StaticArraysCore"]
git-tree-sha1 = "782dd5f4561f5d267313f23853baaaa4c52ea621"
uuid = "163ba53b-c6d8-5494-b064-1a9d43ac40c5"
version = "1.1.0"

[[DiffRules]]
deps = ["IrrationalConstants", "LogExpFunctions", "NaNMath", "Random", "SpecialFunctions"]
git-tree-sha1 = "c5b6685d53f933c11404a3ae9822afe30d522494"
uuid = "b552c78f-8df3-52c6-915a-8e097449b14b"
version = "1.12.2"

[[Distances]]
deps = ["LinearAlgebra", "SparseArrays", "Statistics", "StatsAPI"]
git-tree-sha1 = "3258d0659f812acde79e8a74b11f17ac06d0ca04"
uuid = "b4f34e82-e78d-54a5-968a-f98e89d6e8f7"
version = "0.10.7"

[[Distributed]]
deps = ["Random", "Serialization", "Sockets"]
uuid = "8ba89e20-285c-5b6f-9357-94700520ee1b"

[[Distributions]]
deps = ["ChainRulesCore", "DensityInterface", "FillArrays", "LinearAlgebra", "PDMats", "Printf", "QuadGK", "Random", "SparseArrays", "SpecialFunctions", "Statistics", "StatsBase", "StatsFuns", "Test"]
git-tree-sha1 = "a7756d098cbabec6b3ac44f369f74915e8cfd70a"
uuid = "31c24e10-a181-5473-b8eb-7969acd0382f"
version = "0.25.79"

[[DocStringExtensions]]
deps = ["LibGit2"]
git-tree-sha1 = "2fb1e02f2b635d0845df5d7c167fec4dd739b00d"
uuid = "ffbed154-4ef7-542d-bbb7-c09d3a79fcae"
version = "0.9.3"

[[Downloads]]
deps = ["ArgTools", "FileWatching", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"
version = "1.6.0"

[[DualNumbers]]
deps = ["Calculus", "NaNMath", "SpecialFunctions"]
git-tree-sha1 = "5837a837389fccf076445fce071c8ddaea35a566"
uuid = "fa6b7ba4-c1ee-5f82-b5fc-ecf0adba8f74"
version = "0.6.8"

[[EnumX]]
git-tree-sha1 = "bdb1942cd4c45e3c678fd11569d5cccd80976237"
uuid = "4e289a0a-7415-4d19-859d-a7e5c4648b56"
version = "1.0.4"

[[Expat_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "bad72f730e9e91c08d9427d5e8db95478a3c323d"
uuid = "2e619515-83b5-522b-bb60-26c02a35a201"
version = "2.4.8+0"

[[ExprTools]]
git-tree-sha1 = "56559bbef6ca5ea0c0818fa5c90320398a6fbf8d"
uuid = "e2ba6199-217a-4e67-a87a-7c52f15ade04"
version = "0.1.8"

[[Extents]]
git-tree-sha1 = "5e1e4c53fa39afe63a7d356e30452249365fba99"
uuid = "411431e0-e8b7-467b-b5e0-f676ba4f2910"
version = "0.1.1"

[[FFMPEG]]
deps = ["FFMPEG_jll"]
git-tree-sha1 = "b57e3acbe22f8484b4b5ff66a7499717fe1a9cc8"
uuid = "c87230d0-a227-11e9-1b43-d7ebe4e7570a"
version = "0.4.1"

[[FFMPEG_jll]]
deps = ["Artifacts", "Bzip2_jll", "FreeType2_jll", "FriBidi_jll", "JLLWrappers", "LAME_jll", "Libdl", "Ogg_jll", "OpenSSL_jll", "Opus_jll", "PCRE2_jll", "Pkg", "Zlib_jll", "libaom_jll", "libass_jll", "libfdk_aac_jll", "libvorbis_jll", "x264_jll", "x265_jll"]
git-tree-sha1 = "74faea50c1d007c85837327f6775bea60b5492dd"
uuid = "b22a6f82-2f65-5046-a5b2-351ab43fb4e5"
version = "4.4.2+2"

[[FFTViews]]
deps = ["CustomUnitRanges", "FFTW"]
git-tree-sha1 = "cbdf14d1e8c7c8aacbe8b19862e0179fd08321c2"
uuid = "4f61f5a4-77b1-5117-aa51-3ab5ef4ef0cd"
version = "0.3.2"

[[FFTW]]
deps = ["AbstractFFTs", "FFTW_jll", "LinearAlgebra", "MKL_jll", "Preferences", "Reexport"]
git-tree-sha1 = "90630efff0894f8142308e334473eba54c433549"
uuid = "7a1cc6ca-52ef-59f5-83cd-3a7055c09341"
version = "1.5.0"

[[FFTW_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "c6033cc3892d0ef5bb9cd29b7f2f0331ea5184ea"
uuid = "f5851436-0d7a-5f13-b9de-f02708fd171a"
version = "3.3.10+0"

[[FieldMetadata]]
git-tree-sha1 = "c279c6eab9767a3f62685e5276c850512e0a1afd"
uuid = "bf96fef3-21d2-5d20-8afa-0e7d4c32a885"
version = "0.3.1"

[[FileIO]]
deps = ["Pkg", "Requires", "UUIDs"]
git-tree-sha1 = "7be5f99f7d15578798f338f5433b6c432ea8037b"
uuid = "5789e2e9-d7fb-5bc7-8068-2c6fae9b9549"
version = "1.16.0"

[[FileWatching]]
uuid = "7b1f6079-737a-58dc-b8bc-7a2ca5c1b5ee"

[[FillArrays]]
deps = ["LinearAlgebra", "Random", "SparseArrays", "Statistics"]
git-tree-sha1 = "9a0472ec2f5409db243160a8b030f94c380167a3"
uuid = "1a297f60-69ca-5386-bcde-b61e274b549b"
version = "0.13.6"

[[FixedPointNumbers]]
deps = ["Statistics"]
git-tree-sha1 = "335bfdceacc84c5cdf16aadc768aa5ddfc5383cc"
uuid = "53c48c17-4a7d-5ca2-90c5-79b7896eea93"
version = "0.8.4"

[[Flatten]]
deps = ["ConstructionBase", "FieldMetadata"]
git-tree-sha1 = "d3541c658c7e452fefba6c933c43842282cdfd3e"
uuid = "4c728ea3-d9ee-5c9a-9642-b6f7d7dc04fa"
version = "0.4.3"

[[Fontconfig_jll]]
deps = ["Artifacts", "Bzip2_jll", "Expat_jll", "FreeType2_jll", "JLLWrappers", "Libdl", "Libuuid_jll", "Pkg", "Zlib_jll"]
git-tree-sha1 = "21efd19106a55620a188615da6d3d06cd7f6ee03"
uuid = "a3f928ae-7b40-5064-980b-68af3947d34b"
version = "2.13.93+0"

[[Formatting]]
deps = ["Printf"]
git-tree-sha1 = "8339d61043228fdd3eb658d86c926cb282ae72a8"
uuid = "59287772-0a20-5a39-b81b-1366585eb4c0"
version = "0.4.2"

[[ForwardDiff]]
deps = ["CommonSubexpressions", "DiffResults", "DiffRules", "LinearAlgebra", "LogExpFunctions", "NaNMath", "Preferences", "Printf", "Random", "SpecialFunctions", "StaticArrays"]
git-tree-sha1 = "a69dd6db8a809f78846ff259298678f0d6212180"
uuid = "f6369f11-7733-5829-9624-2563aa707210"
version = "0.10.34"

[[FreeType2_jll]]
deps = ["Artifacts", "Bzip2_jll", "JLLWrappers", "Libdl", "Pkg", "Zlib_jll"]
git-tree-sha1 = "87eb71354d8ec1a96d4a7636bd57a7347dde3ef9"
uuid = "d7e528f0-a631-5988-bf34-fe36492bcfd7"
version = "2.10.4+0"

[[FriBidi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "aa31987c2ba8704e23c6c8ba8a4f769d5d7e4f91"
uuid = "559328eb-81f9-559d-9380-de523a88c83c"
version = "1.0.10+0"

[[FunctionWrappers]]
git-tree-sha1 = "d62485945ce5ae9c0c48f124a84998d755bae00e"
uuid = "069b7b12-0de2-55c6-9aab-29f3d0a68a2e"
version = "1.1.3"

[[FunctionWrappersWrappers]]
deps = ["FunctionWrappers"]
git-tree-sha1 = "a5e6e7f12607e90d71b09e6ce2c965e41b337968"
uuid = "77dc65aa-8811-40c2-897b-53d922fa7daf"
version = "0.1.1"

[[Functors]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "a2657dd0f3e8a61dbe70fc7c122038bd33790af5"
uuid = "d9f16b24-f501-4c13-a1f2-28368ffc5196"
version = "0.3.0"

[[Future]]
deps = ["Random"]
uuid = "9fa8497b-333b-5362-9e8d-4d0656e87820"

[[GLFW_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libglvnd_jll", "Pkg", "Xorg_libXcursor_jll", "Xorg_libXi_jll", "Xorg_libXinerama_jll", "Xorg_libXrandr_jll"]
git-tree-sha1 = "d972031d28c8c8d9d7b41a536ad7bb0c2579caca"
uuid = "0656b61e-2033-5cc2-a64a-77c0f6c09b89"
version = "3.3.8+0"

[[GPUArraysCore]]
deps = ["Adapt"]
git-tree-sha1 = "6872f5ec8fd1a38880f027a26739d42dcda6691f"
uuid = "46192b85-c4d5-4398-a991-12ede77f4527"
version = "0.1.2"

[[GR]]
deps = ["Artifacts", "Base64", "DelimitedFiles", "Downloads", "GR_jll", "HTTP", "JSON", "Libdl", "LinearAlgebra", "Pkg", "Preferences", "Printf", "Random", "Serialization", "Sockets", "TOML", "Tar", "Test", "UUIDs", "p7zip_jll"]
git-tree-sha1 = "387d2b8b3ca57b791633f0993b31d8cb43ea3292"
uuid = "28b8d3ca-fb5f-59d9-8090-bfdbd6d07a71"
version = "0.71.3"

[[GR_jll]]
deps = ["Artifacts", "Bzip2_jll", "Cairo_jll", "FFMPEG_jll", "Fontconfig_jll", "GLFW_jll", "JLLWrappers", "JpegTurbo_jll", "Libdl", "Libtiff_jll", "Pixman_jll", "Pkg", "Qt5Base_jll", "Zlib_jll", "libpng_jll"]
git-tree-sha1 = "5982b5e20f97bff955e9a2343a14da96a746cd8c"
uuid = "d2c73de3-f751-5644-a686-071e5b155ba9"
version = "0.71.3+0"

[[GeoFormatTypes]]
git-tree-sha1 = "434166198434a5c2fcc0a1a59d22c3b0ad460889"
uuid = "68eda718-8dee-11e9-39e7-89f7f65f511f"
version = "0.4.1"

[[GeoInterface]]
deps = ["Extents"]
git-tree-sha1 = "fb28b5dc239d0174d7297310ef7b84a11804dfab"
uuid = "cf35fbd7-0cd7-5166-be24-54bfbe79505f"
version = "1.0.1"

[[GeoInterfaceRecipes]]
deps = ["GeoInterface", "RecipesBase"]
git-tree-sha1 = "29e1ec25cfb6762f503a19495aec347acf867a9e"
uuid = "0329782f-3d07-4b52-b9f6-d3137cf03c7a"
version = "1.0.0"

[[Gettext_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl", "Libiconv_jll", "Pkg", "XML2_jll"]
git-tree-sha1 = "9b02998aba7bf074d14de89f9d37ca24a1a0b046"
uuid = "78b55507-aeef-58d4-861c-77aaff3498b1"
version = "0.21.0+0"

[[Glib_jll]]
deps = ["Artifacts", "Gettext_jll", "JLLWrappers", "Libdl", "Libffi_jll", "Libiconv_jll", "Libmount_jll", "PCRE2_jll", "Pkg", "Zlib_jll"]
git-tree-sha1 = "d3b3624125c1474292d0d8ed0f65554ac37ddb23"
uuid = "7746bdde-850d-59dc-9ae8-88ece973131d"
version = "2.74.0+2"

[[Graphics]]
deps = ["Colors", "LinearAlgebra", "NaNMath"]
git-tree-sha1 = "d61890399bc535850c4bf08e4e0d3a7ad0f21cbd"
uuid = "a2bd30eb-e257-5431-a919-1863eab51364"
version = "1.1.2"

[[Graphite2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "344bf40dcab1073aca04aa0df4fb092f920e4011"
uuid = "3b182d85-2403-5c21-9c21-1e1f0cc25472"
version = "1.3.14+0"

[[Grisu]]
git-tree-sha1 = "53bb909d1151e57e2484c3d1b53e19552b887fb2"
uuid = "42e2da0e-8278-4e71-bc24-59509adca0fe"
version = "1.0.2"

[[HDF5]]
deps = ["Compat", "HDF5_jll", "Libdl", "Mmap", "Random", "Requires", "UUIDs"]
git-tree-sha1 = "b5df7c3cab3a00c33c2e09c6bd23982a75e2fbb2"
uuid = "f67ccb44-e63f-5c2f-98bd-6dc0ccc4ba2f"
version = "0.16.13"

[[HDF5_jll]]
deps = ["Artifacts", "JLLWrappers", "LibCURL_jll", "Libdl", "OpenSSL_jll", "Pkg", "Zlib_jll"]
git-tree-sha1 = "4cc2bb72df6ff40b055295fdef6d92955f9dede8"
uuid = "0234f1f7-429e-5d53-9886-15a909be8d59"
version = "1.12.2+2"

[[HTTP]]
deps = ["Base64", "CodecZlib", "Dates", "IniFile", "Logging", "LoggingExtras", "MbedTLS", "NetworkOptions", "OpenSSL", "Random", "SimpleBufferStream", "Sockets", "URIs", "UUIDs"]
git-tree-sha1 = "fd9861adba6b9ae4b42582032d0936d456c8602d"
uuid = "cd3eb016-35fb-5094-929b-558a96fad6f3"
version = "1.6.3"

[[HarfBuzz_jll]]
deps = ["Artifacts", "Cairo_jll", "Fontconfig_jll", "FreeType2_jll", "Glib_jll", "Graphite2_jll", "JLLWrappers", "Libdl", "Libffi_jll", "Pkg"]
git-tree-sha1 = "129acf094d168394e80ee1dc4bc06ec835e510a3"
uuid = "2e76f6c2-a576-52d4-95c1-20adfe4de566"
version = "2.8.1+1"

[[HypergeometricFunctions]]
deps = ["DualNumbers", "LinearAlgebra", "OpenLibm_jll", "SpecialFunctions", "Test"]
git-tree-sha1 = "709d864e3ed6e3545230601f94e11ebc65994641"
uuid = "34004b35-14d8-5ef3-9330-4cdb6864b03a"
version = "0.3.11"

[[Hyperscript]]
deps = ["Test"]
git-tree-sha1 = "8d511d5b81240fc8e6802386302675bdf47737b9"
uuid = "47d2ed2b-36de-50cf-bf87-49c2cf4b8b91"
version = "0.0.4"

[[HypertextLiteral]]
deps = ["Tricks"]
git-tree-sha1 = "c47c5fa4c5308f27ccaac35504858d8914e102f9"
uuid = "ac1192a8-f4b3-4bfe-ba22-af5b92cd3ab2"
version = "0.9.4"

[[IOCapture]]
deps = ["Logging", "Random"]
git-tree-sha1 = "f7be53659ab06ddc986428d3a9dcc95f6fa6705a"
uuid = "b5f81e59-6552-4d32-b1f0-c071b021bf89"
version = "0.2.2"

[[IfElse]]
git-tree-sha1 = "debdd00ffef04665ccbb3e150747a77560e8fad1"
uuid = "615f187c-cbe4-4ef1-ba3b-2fcf58d6d173"
version = "0.1.1"

[[ImageBase]]
deps = ["ImageCore", "Reexport"]
git-tree-sha1 = "b51bb8cae22c66d0f6357e3bcb6363145ef20835"
uuid = "c817782e-172a-44cc-b673-b171935fbb9e"
version = "0.1.5"

[[ImageCore]]
deps = ["AbstractFFTs", "ColorVectorSpace", "Colors", "FixedPointNumbers", "Graphics", "MappedArrays", "MosaicViews", "OffsetArrays", "PaddedViews", "Reexport"]
git-tree-sha1 = "acf614720ef026d38400b3817614c45882d75500"
uuid = "a09fc81d-aa75-5fe9-8630-4744c3626534"
version = "0.9.4"

[[ImageFiltering]]
deps = ["CatIndices", "ComputationalResources", "DataStructures", "FFTViews", "FFTW", "ImageBase", "ImageCore", "LinearAlgebra", "OffsetArrays", "Reexport", "SnoopPrecompile", "SparseArrays", "StaticArrays", "Statistics", "TiledIteration"]
git-tree-sha1 = "f265e53558fbbf23e0d54e4fab7106c0f2a9e576"
uuid = "6a3955dd-da59-5b1f-98d4-e7296123deb5"
version = "0.7.3"

[[IniFile]]
git-tree-sha1 = "f550e6e32074c939295eb5ea6de31849ac2c9625"
uuid = "83e8ac13-25f8-5344-8a64-a9f2b223428f"
version = "0.5.1"

[[InlineStrings]]
deps = ["Parsers"]
git-tree-sha1 = "0cf92ec945125946352f3d46c96976ab972bde6f"
uuid = "842dd82b-1e85-43dc-bf29-5d0ee9dffc48"
version = "1.3.2"

[[Inpaintings]]
deps = ["LinearAlgebra", "Match", "SparseArrays", "SuiteSparse", "Test"]
git-tree-sha1 = "583dc8ed254875bf07b01939c339a431e3470a99"
uuid = "a3d749fb-087c-5225-80b3-65fbd02ae0fd"
version = "0.3.0"

[[IntelOpenMP_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "d979e54b71da82f3a65b62553da4fc3d18c9004c"
uuid = "1d5cc7b8-4909-519e-a0f8-d0f5ad9712d0"
version = "2018.0.3+2"

[[InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"

[[Interpolations]]
deps = ["Adapt", "AxisAlgorithms", "ChainRulesCore", "LinearAlgebra", "OffsetArrays", "Random", "Ratios", "Requires", "SharedArrays", "SparseArrays", "StaticArrays", "WoodburyMatrices"]
git-tree-sha1 = "721ec2cf720536ad005cb38f50dbba7b02419a15"
uuid = "a98d9a8b-a2ab-59e6-89dd-64a1c18fca59"
version = "0.14.7"

[[InverseFunctions]]
deps = ["Test"]
git-tree-sha1 = "49510dfcb407e572524ba94aeae2fced1f3feb0f"
uuid = "3587e190-3f89-42d0-90ee-14403ec27112"
version = "0.1.8"

[[InvertedIndices]]
git-tree-sha1 = "82aec7a3dd64f4d9584659dc0b62ef7db2ef3e19"
uuid = "41ab1584-1d38-5bbf-9106-f11c6c58b48f"
version = "1.2.0"

[[IrrationalConstants]]
git-tree-sha1 = "7fd44fd4ff43fc60815f8e764c0f352b83c49151"
uuid = "92d709cd-6900-40b7-9082-c6be49f344b6"
version = "0.1.1"

[[IteratorInterfaceExtensions]]
git-tree-sha1 = "a3f24677c21f5bbe9d2a714f95dcd58337fb2856"
uuid = "82899510-4779-5014-852e-03e436cf321d"
version = "1.0.0"

[[JLD2]]
deps = ["FileIO", "MacroTools", "Mmap", "OrderedCollections", "Pkg", "Printf", "Reexport", "TranscodingStreams", "UUIDs"]
git-tree-sha1 = "ec8a9c9f0ecb1c687e34c1fda2699de4d054672a"
uuid = "033835bb-8acc-5ee8-8aae-3f567f8a3819"
version = "0.4.29"

[[JLFzf]]
deps = ["Pipe", "REPL", "Random", "fzf_jll"]
git-tree-sha1 = "f377670cda23b6b7c1c0b3893e37451c5c1a2185"
uuid = "1019f520-868f-41f5-a6de-eb00f4b6a39c"
version = "0.1.5"

[[JLLWrappers]]
deps = ["Preferences"]
git-tree-sha1 = "abc9885a7ca2052a736a600f7fa66209f96506e1"
uuid = "692b3bcd-3c85-4b1f-b108-f13ce0eb3210"
version = "1.4.1"

[[JSON]]
deps = ["Dates", "Mmap", "Parsers", "Unicode"]
git-tree-sha1 = "3c837543ddb02250ef42f4738347454f95079d4e"
uuid = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
version = "0.21.3"

[[JpegTurbo_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "b53380851c6e6664204efb2e62cd24fa5c47e4ba"
uuid = "aacddb02-875f-59d6-b918-886e6ef4fbf8"
version = "2.1.2+0"

[[LAME_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "f6250b16881adf048549549fba48b1161acdac8c"
uuid = "c1c5ebd0-6772-5130-a774-d5fcae4a789d"
version = "3.100.1+0"

[[LERC_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "bf36f528eec6634efc60d7ec062008f171071434"
uuid = "88015f11-f218-50d7-93a8-a6af411a945d"
version = "3.0.0+1"

[[LZO_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "e5b909bcf985c5e2605737d2ce278ed791b89be6"
uuid = "dd4b983a-f0e5-5f8d-a1b7-129d4a5fb1ac"
version = "2.10.1+0"

[[LaTeXStrings]]
git-tree-sha1 = "f2355693d6778a178ade15952b7ac47a4ff97996"
uuid = "b964fa9f-0449-5b57-a5c2-d3ea65f4040f"
version = "1.3.0"

[[Latexify]]
deps = ["Formatting", "InteractiveUtils", "LaTeXStrings", "MacroTools", "Markdown", "OrderedCollections", "Printf", "Requires"]
git-tree-sha1 = "2422f47b34d4b127720a18f86fa7b1aa2e141f29"
uuid = "23fbe1c1-3f47-55db-b15f-69d7ec21a316"
version = "0.15.18"

[[LazyArtifacts]]
deps = ["Artifacts", "Pkg"]
uuid = "4af54fe1-eca0-43a8-85a7-787d91b784e3"

[[LibCURL]]
deps = ["LibCURL_jll", "MozillaCACerts_jll"]
uuid = "b27032c2-a3e7-50c8-80cd-2d36dbcbfd21"
version = "0.6.3"

[[LibCURL_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll", "Zlib_jll", "nghttp2_jll"]
uuid = "deac9b47-8bc7-5906-a0fe-35ac56dc84c0"
version = "7.84.0+0"

[[LibGit2]]
deps = ["Base64", "NetworkOptions", "Printf", "SHA"]
uuid = "76f85450-5226-5b5a-8eaa-529ad045b433"

[[LibSSH2_jll]]
deps = ["Artifacts", "Libdl", "MbedTLS_jll"]
uuid = "29816b5a-b9ab-546f-933c-edad1886dfa8"
version = "1.10.2+0"

[[Libdl]]
uuid = "8f399da3-3557-5675-b5ff-fb832c97cbdb"

[[Libffi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "0b4a5d71f3e5200a7dff793393e09dfc2d874290"
uuid = "e9f186c6-92d2-5b65-8a66-fee21dc1b490"
version = "3.2.2+1"

[[Libgcrypt_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libgpg_error_jll", "Pkg"]
git-tree-sha1 = "64613c82a59c120435c067c2b809fc61cf5166ae"
uuid = "d4300ac3-e22c-5743-9152-c294e39db1e4"
version = "1.8.7+0"

[[Libglvnd_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll", "Xorg_libXext_jll"]
git-tree-sha1 = "6f73d1dd803986947b2c750138528a999a6c7733"
uuid = "7e76a0d4-f3c7-5321-8279-8d96eeed0f29"
version = "1.6.0+0"

[[Libgpg_error_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "c333716e46366857753e273ce6a69ee0945a6db9"
uuid = "7add5ba3-2f88-524e-9cd5-f83b8a55f7b8"
version = "1.42.0+0"

[[Libiconv_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "c7cb1f5d892775ba13767a87c7ada0b980ea0a71"
uuid = "94ce4f54-9a6c-5748-9c1c-f9c7231a4531"
version = "1.16.1+2"

[[Libmount_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "9c30530bf0effd46e15e0fdcf2b8636e78cbbd73"
uuid = "4b2f31a3-9ecc-558c-b454-b3730dcb73e9"
version = "2.35.0+0"

[[Libtiff_jll]]
deps = ["Artifacts", "JLLWrappers", "JpegTurbo_jll", "LERC_jll", "Libdl", "Pkg", "Zlib_jll", "Zstd_jll"]
git-tree-sha1 = "3eb79b0ca5764d4799c06699573fd8f533259713"
uuid = "89763e89-9b03-5906-acba-b20f662cd828"
version = "4.4.0+0"

[[Libuuid_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "7f3efec06033682db852f8b3bc3c1d2b0a0ab066"
uuid = "38a345b3-de98-5d2b-a5d3-14cd9215e700"
version = "2.36.0+0"

[[LinearAlgebra]]
deps = ["Libdl", "libblastrampoline_jll"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"

[[LogExpFunctions]]
deps = ["ChainRulesCore", "ChangesOfVariables", "DocStringExtensions", "InverseFunctions", "IrrationalConstants", "LinearAlgebra"]
git-tree-sha1 = "946607f84feb96220f480e0422d3484c49c00239"
uuid = "2ab3a3ac-af41-5b50-aa03-7779005ae688"
version = "0.3.19"

[[Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"

[[LoggingExtras]]
deps = ["Dates", "Logging"]
git-tree-sha1 = "cedb76b37bc5a6c702ade66be44f831fa23c681e"
uuid = "e6f89c97-d47a-5376-807f-9c37f3926c36"
version = "1.0.0"

[[MAT]]
deps = ["BufferedStreams", "CodecZlib", "HDF5", "SparseArrays"]
git-tree-sha1 = "971be550166fe3f604d28715302b58a3f7293160"
uuid = "23992714-dd62-5051-b70f-ba57cb901cac"
version = "0.10.3"

[[MIMEs]]
git-tree-sha1 = "65f28ad4b594aebe22157d6fac869786a255b7eb"
uuid = "6c6e2e6c-3030-632d-7369-2d6c69616d65"
version = "0.1.4"

[[MKL_jll]]
deps = ["Artifacts", "IntelOpenMP_jll", "JLLWrappers", "LazyArtifacts", "Libdl", "Pkg"]
git-tree-sha1 = "2ce8695e1e699b68702c03402672a69f54b8aca9"
uuid = "856f044c-d86e-5d09-b602-aeab76dc8ba7"
version = "2022.2.0+0"

[[MacroTools]]
deps = ["Markdown", "Random"]
git-tree-sha1 = "42324d08725e200c23d4dfb549e0d5d89dede2d2"
uuid = "1914dd2f-81c6-5fcd-8719-6d5c9610ff09"
version = "0.5.10"

[[MappedArrays]]
git-tree-sha1 = "e8b359ef06ec72e8c030463fe02efe5527ee5142"
uuid = "dbb5928d-eab1-5f90-85c2-b9b0edb7c900"
version = "0.4.1"

[[Markdown]]
deps = ["Base64"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"

[[Match]]
git-tree-sha1 = "1d9bc5c1a6e7ee24effb93f175c9342f9154d97f"
uuid = "7eb4fadd-790c-5f42-8a69-bfa0b872bfbf"
version = "1.2.0"

[[MbedTLS]]
deps = ["Dates", "MbedTLS_jll", "MozillaCACerts_jll", "Random", "Sockets"]
git-tree-sha1 = "03a9b9718f5682ecb107ac9f7308991db4ce395b"
uuid = "739be429-bea8-5141-9913-cc70e7f3736d"
version = "1.1.7"

[[MbedTLS_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "c8ffd9c3-330d-5841-b78e-0817d7145fa1"
version = "2.28.0+0"

[[Measures]]
git-tree-sha1 = "c13304c81eec1ed3af7fc20e75fb6b26092a1102"
uuid = "442fdcdd-2543-5da2-b0f3-8c86c306513e"
version = "0.3.2"

[[MetadataArrays]]
git-tree-sha1 = "fea53b6812f0fd3b12041f2652fbd214e36605bf"
uuid = "49441bc9-da82-574f-b07c-a0d10dd4ac13"
version = "0.1.1"

[[Missings]]
deps = ["DataAPI"]
git-tree-sha1 = "f66bdc5de519e8f8ae43bdc598782d35a25b1272"
uuid = "e1d29d7a-bbdc-5cf2-9ac0-f12de2c33e28"
version = "1.1.0"

[[Mmap]]
uuid = "a63ad114-7e13-5084-954f-fe012c677804"

[[MosaicViews]]
deps = ["MappedArrays", "OffsetArrays", "PaddedViews", "StackViews"]
git-tree-sha1 = "7b86a5d4d70a9f5cdf2dacb3cbe6d251d1a61dbe"
uuid = "e94cdb99-869f-56ef-bcf0-1ae2bcbe0389"
version = "0.3.4"

[[MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"
version = "2022.2.1"

[[NCDatasets]]
deps = ["CFTime", "DataStructures", "Dates", "NetCDF_jll", "NetworkOptions", "Printf"]
git-tree-sha1 = "bf3e94c52b7e00935131ae5edc1b45c745502332"
uuid = "85f8d34a-cbdd-5861-8df4-14fed0d494ab"
version = "0.12.11"

[[NaNMath]]
deps = ["OpenLibm_jll"]
git-tree-sha1 = "a7c3d1da1189a1c2fe843a3bfa04d18d20eb3211"
uuid = "77ba4419-2d1f-58cd-9bb1-8ffee604a2e3"
version = "1.0.1"

[[NearestNeighbors]]
deps = ["Distances", "StaticArrays"]
git-tree-sha1 = "2c3726ceb3388917602169bed973dbc97f1b51a8"
uuid = "b8a86587-4115-5ab1-83bc-aa920d37bbce"
version = "0.4.13"

[[NetCDF_jll]]
deps = ["Artifacts", "HDF5_jll", "JLLWrappers", "LibCURL_jll", "Libdl", "Pkg", "XML2_jll", "Zlib_jll"]
git-tree-sha1 = "072f8371f74c3b9e1b26679de7fbf059d45ea221"
uuid = "7243133f-43d8-5620-bbf4-c2c921802cf3"
version = "400.902.5+1"

[[NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"
version = "1.2.0"

[[OceanBasins]]
deps = ["DataDeps", "DelimitedFiles", "PolygonOps", "StaticArrays"]
git-tree-sha1 = "35c7c6274418986991573d024e6173126e7fb335"
uuid = "d1bb7020-b2be-4340-9d18-d24ca645bddb"
version = "0.1.7"

[[OceanGrids]]
deps = ["Inpaintings", "Interpolations", "LinearAlgebra", "NearestNeighbors", "SparseArrays", "Unitful"]
git-tree-sha1 = "e17442910f5abd83e8e577c681f7fda6d7991f0d"
uuid = "cfe838f4-859f-11e9-2ea1-df7d4e7c3537"
version = "0.4.5"

[[OffsetArrays]]
deps = ["Adapt"]
git-tree-sha1 = "f71d8950b724e9ff6110fc948dff5a329f901d64"
uuid = "6fe1bfb0-de20-5000-8ca7-80f57d26f881"
version = "1.12.8"

[[Ogg_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "887579a3eb005446d514ab7aeac5d1d027658b8f"
uuid = "e7412a2a-1a6e-54c0-be00-318e2571c051"
version = "1.3.5+1"

[[OpenBLAS_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "4536629a-c528-5b80-bd46-f80d51c5b363"
version = "0.3.20+0"

[[OpenLibm_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "05823500-19ac-5b8b-9628-191a04bc5112"
version = "0.8.1+0"

[[OpenSSL]]
deps = ["BitFlags", "Dates", "MozillaCACerts_jll", "OpenSSL_jll", "Sockets"]
git-tree-sha1 = "df6830e37943c7aaa10023471ca47fb3065cc3c4"
uuid = "4d8831e6-92b7-49fb-bdf8-b643e874388c"
version = "1.3.2"

[[OpenSSL_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "f6e9dba33f9f2c44e08a020b0caf6903be540004"
uuid = "458c3c95-2e84-50aa-8efc-19380b2a3a95"
version = "1.1.19+0"

[[OpenSpecFun_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "13652491f6856acfd2db29360e1bbcd4565d04f1"
uuid = "efe28fd5-8261-553b-a9e1-b2916fc3738e"
version = "0.5.5+0"

[[Opus_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "51a08fb14ec28da2ec7a927c4337e4332c2a4720"
uuid = "91d4177d-7536-5919-b921-800302f37372"
version = "1.3.2+0"

[[OrderedCollections]]
git-tree-sha1 = "85f8e6578bf1f9ee0d11e7bb1b1456435479d47c"
uuid = "bac558e1-5e72-5ebc-8fee-abe8a469f55d"
version = "1.4.1"

[[PCRE2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "efcefdf7-47ab-520b-bdef-62a2eaa19f15"
version = "10.40.0+0"

[[PDMats]]
deps = ["LinearAlgebra", "SparseArrays", "SuiteSparse"]
git-tree-sha1 = "cf494dca75a69712a72b80bc48f59dcf3dea63ec"
uuid = "90014a1f-27ba-587c-ab20-58faa44d9150"
version = "0.11.16"

[[PaddedViews]]
deps = ["OffsetArrays"]
git-tree-sha1 = "03a7a85b76381a3d04c7a1656039197e70eda03d"
uuid = "5432bcbf-9aad-5242-b902-cca2824c8663"
version = "0.5.11"

[[Parsers]]
deps = ["Dates", "SnoopPrecompile"]
git-tree-sha1 = "6466e524967496866901a78fca3f2e9ea445a559"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "2.5.2"

[[Pipe]]
git-tree-sha1 = "6842804e7867b115ca9de748a0cf6b364523c16d"
uuid = "b98c9c47-44ae-5843-9183-064241ee97a0"
version = "1.3.0"

[[Pixman_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "b4f5d02549a10e20780a24fce72bea96b6329e29"
uuid = "30392449-352a-5448-841d-b1acce4e97dc"
version = "0.40.1+0"

[[Pkg]]
deps = ["Artifacts", "Dates", "Downloads", "LibGit2", "Libdl", "Logging", "Markdown", "Printf", "REPL", "Random", "SHA", "Serialization", "TOML", "Tar", "UUIDs", "p7zip_jll"]
uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"
version = "1.8.0"

[[PlotThemes]]
deps = ["PlotUtils", "Statistics"]
git-tree-sha1 = "1f03a2d339f42dca4a4da149c7e15e9b896ad899"
uuid = "ccf2f8ad-2431-5c83-bf29-c5338b663b6a"
version = "3.1.0"

[[PlotUtils]]
deps = ["ColorSchemes", "Colors", "Dates", "Printf", "Random", "Reexport", "SnoopPrecompile", "Statistics"]
git-tree-sha1 = "5b7690dd212e026bbab1860016a6601cb077ab66"
uuid = "995b91a9-d308-5afd-9ec6-746e21dbc043"
version = "1.3.2"

[[Plots]]
deps = ["Base64", "Contour", "Dates", "Downloads", "FFMPEG", "FixedPointNumbers", "GR", "JLFzf", "JSON", "LaTeXStrings", "Latexify", "LinearAlgebra", "Measures", "NaNMath", "Pkg", "PlotThemes", "PlotUtils", "Preferences", "Printf", "REPL", "Random", "RecipesBase", "RecipesPipeline", "Reexport", "RelocatableFolders", "Requires", "Scratch", "Showoff", "SnoopPrecompile", "SparseArrays", "Statistics", "StatsBase", "UUIDs", "UnicodeFun", "Unzip"]
git-tree-sha1 = "02ecc6a3427e7edfff1cebcf66c1f93dd77760ec"
uuid = "91a5bcdd-55d7-5caf-9e0b-520d859cae80"
version = "1.38.1"

[[PlutoUI]]
deps = ["AbstractPlutoDingetjes", "Base64", "ColorTypes", "Dates", "FixedPointNumbers", "Hyperscript", "HypertextLiteral", "IOCapture", "InteractiveUtils", "JSON", "Logging", "MIMEs", "Markdown", "Random", "Reexport", "URIs", "UUIDs"]
git-tree-sha1 = "eadad7b14cf046de6eb41f13c9275e5aa2711ab6"
uuid = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
version = "0.7.49"

[[PolygonOps]]
git-tree-sha1 = "77b3d3605fc1cd0b42d95eba87dfcd2bf67d5ff6"
uuid = "647866c9-e3ac-4575-94e7-e3d426903924"
version = "0.1.2"

[[PooledArrays]]
deps = ["DataAPI", "Future"]
git-tree-sha1 = "a6062fe4063cdafe78f4a0a81cfffb89721b30e7"
uuid = "2dfb63ee-cc39-5dd5-95bd-886bf059d720"
version = "1.4.2"

[[Preferences]]
deps = ["TOML"]
git-tree-sha1 = "47e5f437cc0e7ef2ce8406ce1e7e24d44915f88d"
uuid = "21216c6a-2e73-6563-6e65-726566657250"
version = "1.3.0"

[[PrettyTables]]
deps = ["Crayons", "Formatting", "LaTeXStrings", "Markdown", "Reexport", "StringManipulation", "Tables"]
git-tree-sha1 = "96f6db03ab535bdb901300f88335257b0018689d"
uuid = "08abe8d2-0d0c-5749-adfa-8a2ac140af0d"
version = "2.2.2"

[[Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"

[[Qt5Base_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Fontconfig_jll", "Glib_jll", "JLLWrappers", "Libdl", "Libglvnd_jll", "OpenSSL_jll", "Pkg", "Xorg_libXext_jll", "Xorg_libxcb_jll", "Xorg_xcb_util_image_jll", "Xorg_xcb_util_keysyms_jll", "Xorg_xcb_util_renderutil_jll", "Xorg_xcb_util_wm_jll", "Zlib_jll", "xkbcommon_jll"]
git-tree-sha1 = "0c03844e2231e12fda4d0086fd7cbe4098ee8dc5"
uuid = "ea2cea3b-5b76-57ae-a6ef-0a8af62496e1"
version = "5.15.3+2"

[[QuadGK]]
deps = ["DataStructures", "LinearAlgebra"]
git-tree-sha1 = "97aa253e65b784fd13e83774cadc95b38011d734"
uuid = "1fd47b50-473d-5c70-9696-f719f8f3bcdc"
version = "2.6.0"

[[REPL]]
deps = ["InteractiveUtils", "Markdown", "Sockets", "Unicode"]
uuid = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"

[[Random]]
deps = ["SHA", "Serialization"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"

[[Ratios]]
deps = ["Requires"]
git-tree-sha1 = "dc84268fe0e3335a62e315a3a7cf2afa7178a734"
uuid = "c84ed2f1-dad5-54f0-aa8e-dbefe2724439"
version = "0.4.3"

[[RecipesBase]]
deps = ["SnoopPrecompile"]
git-tree-sha1 = "261dddd3b862bd2c940cf6ca4d1c8fe593e457c8"
uuid = "3cdcf5f2-1ef4-517c-9805-6587b60abb01"
version = "1.3.3"

[[RecipesPipeline]]
deps = ["Dates", "NaNMath", "PlotUtils", "RecipesBase", "SnoopPrecompile"]
git-tree-sha1 = "e974477be88cb5e3040009f3767611bc6357846f"
uuid = "01d81517-befc-4cb6-b9ec-a95719d0359c"
version = "0.6.11"

[[RecursiveArrayTools]]
deps = ["Adapt", "ArrayInterfaceCore", "ArrayInterfaceStaticArraysCore", "ChainRulesCore", "DocStringExtensions", "FillArrays", "GPUArraysCore", "IteratorInterfaceExtensions", "LinearAlgebra", "RecipesBase", "StaticArraysCore", "Statistics", "SymbolicIndexingInterface", "Tables", "ZygoteRules"]
git-tree-sha1 = "66e6a85fd5469429a3ac30de1bd491e48a6bac00"
uuid = "731186ca-8d62-57ce-b412-fbd966d074cd"
version = "2.34.1"

[[Reexport]]
git-tree-sha1 = "45e428421666073eab6f2da5c9d310d99bb12f9b"
uuid = "189a3867-3050-52da-a836-e630ba90ab69"
version = "1.2.2"

[[RelocatableFolders]]
deps = ["SHA", "Scratch"]
git-tree-sha1 = "90bc7a7c96410424509e4263e277e43250c05691"
uuid = "05181044-ff0b-4ac5-8273-598c1e38db00"
version = "1.0.0"

[[Requires]]
deps = ["UUIDs"]
git-tree-sha1 = "838a3a4188e2ded87a4f9f184b4b0d78a1e91cb7"
uuid = "ae029012-a4dd-5104-9daa-d747884805df"
version = "1.3.0"

[[Rmath]]
deps = ["Random", "Rmath_jll"]
git-tree-sha1 = "bf3188feca147ce108c76ad82c2792c57abe7b1f"
uuid = "79098fc4-a85e-5d69-aa6a-4863f24498fa"
version = "0.7.0"

[[Rmath_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "68db32dff12bb6127bac73c209881191bf0efbb7"
uuid = "f50d1b31-88e8-58de-be2c-1cc44531875f"
version = "0.3.0+0"

[[Roots]]
deps = ["ChainRulesCore", "CommonSolve", "Printf", "Setfield"]
git-tree-sha1 = "a3db467ce768343235032a1ca0830fc64158dadf"
uuid = "f2b01f46-fcfa-551c-844a-d8ac1e96c665"
version = "2.0.8"

[[RuntimeGeneratedFunctions]]
deps = ["ExprTools", "SHA", "Serialization"]
git-tree-sha1 = "50314d2ef65fce648975a8e80ae6d8409ebbf835"
uuid = "7e49a35a-f44a-4d26-94aa-eba1b4ca6b47"
version = "0.5.5"

[[SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"
version = "0.7.0"

[[SciMLBase]]
deps = ["ArrayInterfaceCore", "CommonSolve", "ConstructionBase", "Distributed", "DocStringExtensions", "EnumX", "FunctionWrappersWrappers", "IteratorInterfaceExtensions", "LinearAlgebra", "Logging", "Markdown", "Preferences", "RecipesBase", "RecursiveArrayTools", "RuntimeGeneratedFunctions", "StaticArraysCore", "Statistics", "Tables"]
git-tree-sha1 = "fe89a8113ea445bcff9ee570077830674babb534"
uuid = "0bca4576-84f4-4d90-8ffe-ffa030f20462"
version = "1.81.0"

[[Scratch]]
deps = ["Dates"]
git-tree-sha1 = "f94f779c94e58bf9ea243e77a37e16d9de9126bd"
uuid = "6c6a2e73-6563-6170-7368-637461726353"
version = "1.1.1"

[[Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"

[[Setfield]]
deps = ["ConstructionBase", "Future", "MacroTools", "StaticArraysCore"]
git-tree-sha1 = "e2cc6d8c88613c05e1defb55170bf5ff211fbeac"
uuid = "efcf1570-3423-57d1-acb7-fd33fddbac46"
version = "1.1.1"

[[Shapefile]]
deps = ["DBFTables", "Extents", "GeoFormatTypes", "GeoInterface", "GeoInterfaceRecipes", "RecipesBase", "Tables"]
git-tree-sha1 = "2f400236c85ba357dfdc2a56af80c939dc118f02"
uuid = "8e980c4a-a4fe-5da2-b3a7-4b4b0353a2f4"
version = "0.8.0"

[[SharedArrays]]
deps = ["Distributed", "Mmap", "Random", "Serialization"]
uuid = "1a1011a3-84de-559e-8e89-a11a2f7dc383"

[[Showoff]]
deps = ["Dates", "Grisu"]
git-tree-sha1 = "91eddf657aca81df9ae6ceb20b959ae5653ad1de"
uuid = "992d4aef-0814-514b-bc4d-f2e9a6c4116f"
version = "1.0.3"

[[SimpleBufferStream]]
git-tree-sha1 = "874e8867b33a00e784c8a7e4b60afe9e037b74e1"
uuid = "777ac1f9-54b0-4bf8-805c-2214025038e7"
version = "1.1.0"

[[SnoopPrecompile]]
git-tree-sha1 = "f604441450a3c0569830946e5b33b78c928e1a85"
uuid = "66db9d55-30c0-4569-8b51-7e840670fc0c"
version = "1.0.1"

[[Sockets]]
uuid = "6462fe0b-24de-5631-8697-dd941f90decc"

[[SortingAlgorithms]]
deps = ["DataStructures"]
git-tree-sha1 = "a4ada03f999bd01b3a25dcaa30b2d929fe537e00"
uuid = "a2af1166-a08f-5f64-846c-94a0d3cef48c"
version = "1.1.0"

[[SparseArrays]]
deps = ["LinearAlgebra", "Random"]
uuid = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"

[[SpecialFunctions]]
deps = ["ChainRulesCore", "IrrationalConstants", "LogExpFunctions", "OpenLibm_jll", "OpenSpecFun_jll"]
git-tree-sha1 = "d75bda01f8c31ebb72df80a46c88b25d1c79c56d"
uuid = "276daf66-3868-5448-9aa4-cd146d93841b"
version = "2.1.7"

[[StackViews]]
deps = ["OffsetArrays"]
git-tree-sha1 = "46e589465204cd0c08b4bd97385e4fa79a0c770c"
uuid = "cae243ae-269e-4f55-b966-ac2d0dc13c15"
version = "0.1.1"

[[Static]]
deps = ["IfElse"]
git-tree-sha1 = "c35b107b61e7f34fa3f124026f2a9be97dea9e1c"
uuid = "aedffcd0-7271-4cad-89d0-dc628f76c6d3"
version = "0.8.3"

[[StaticArrays]]
deps = ["LinearAlgebra", "Random", "StaticArraysCore", "Statistics"]
git-tree-sha1 = "6954a456979f23d05085727adb17c4551c19ecd1"
uuid = "90137ffa-7385-5640-81b9-e52037218182"
version = "1.5.12"

[[StaticArraysCore]]
git-tree-sha1 = "6b7ba252635a5eff6a0b0664a41ee140a1c9e72a"
uuid = "1e83bf80-4336-4d27-bf5d-d5a4f845583c"
version = "1.4.0"

[[Statistics]]
deps = ["LinearAlgebra", "SparseArrays"]
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"

[[StatsAPI]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "f9af7f195fb13589dd2e2d57fdb401717d2eb1f6"
uuid = "82ae8749-77ed-4fe6-ae5f-f523153014b0"
version = "1.5.0"

[[StatsBase]]
deps = ["DataAPI", "DataStructures", "LinearAlgebra", "LogExpFunctions", "Missings", "Printf", "Random", "SortingAlgorithms", "SparseArrays", "Statistics", "StatsAPI"]
git-tree-sha1 = "d1bf48bfcc554a3761a133fe3a9bb01488e06916"
uuid = "2913bbd2-ae8a-5f71-8c99-4fb6c76f3a91"
version = "0.33.21"

[[StatsFuns]]
deps = ["ChainRulesCore", "HypergeometricFunctions", "InverseFunctions", "IrrationalConstants", "LogExpFunctions", "Reexport", "Rmath", "SpecialFunctions"]
git-tree-sha1 = "ab6083f09b3e617e34a956b43e9d51b824206932"
uuid = "4c63d2b9-4356-54db-8cca-17b64c39e42c"
version = "1.1.1"

[[StringDistances]]
deps = ["Distances", "StatsAPI"]
git-tree-sha1 = "ceeef74797d961aee825aabf71446d6aba898acb"
uuid = "88034a9c-02f8-509d-84a9-84ec65e18404"
version = "0.11.2"

[[StringManipulation]]
git-tree-sha1 = "46da2434b41f41ac3594ee9816ce5541c6096123"
uuid = "892a3eda-7b42-436c-8928-eab12a02cf0e"
version = "0.3.0"

[[SuiteSparse]]
deps = ["Libdl", "LinearAlgebra", "Serialization", "SparseArrays"]
uuid = "4607b0f0-06f3-5cda-b6b1-a6196a1729e9"

[[SymbolicIndexingInterface]]
deps = ["DocStringExtensions"]
git-tree-sha1 = "6b764c160547240d868be4e961a5037f47ad7379"
uuid = "2efcf032-c050-4f8e-a9bb-153293bab1f5"
version = "0.2.1"

[[TOML]]
deps = ["Dates"]
uuid = "fa267f1f-6049-4f14-aa54-33bafae1ed76"
version = "1.0.0"

[[TableTraits]]
deps = ["IteratorInterfaceExtensions"]
git-tree-sha1 = "c06b2f539df1c6efa794486abfb6ed2022561a39"
uuid = "3783bdb8-4a98-5b6b-af9a-565f29a5fe9c"
version = "1.0.1"

[[Tables]]
deps = ["DataAPI", "DataValueInterfaces", "IteratorInterfaceExtensions", "LinearAlgebra", "OrderedCollections", "TableTraits", "Test"]
git-tree-sha1 = "c79322d36826aa2f4fd8ecfa96ddb47b174ac78d"
uuid = "bd369af6-aec1-5ad0-b16a-f7cc5008161c"
version = "1.10.0"

[[Tar]]
deps = ["ArgTools", "SHA"]
uuid = "a4e569a6-e804-4fa4-b0f3-eef7a1d5b13e"
version = "1.10.1"

[[TensorCore]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "1feb45f88d133a655e001435632f019a9a1bcdb6"
uuid = "62fd8b95-f654-4bbd-a8a5-9c27f68ccd50"
version = "0.1.1"

[[Test]]
deps = ["InteractiveUtils", "Logging", "Random", "Serialization"]
uuid = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

[[TiledIteration]]
deps = ["ArrayInterface", "OffsetArrays"]
git-tree-sha1 = "1bf2bb587a7fc99fefac2ff076b18b500128e9c0"
uuid = "06e1c1a7-607b-532d-9fad-de7d9aa2abac"
version = "0.4.2"

[[TranscodingStreams]]
deps = ["Random", "Test"]
git-tree-sha1 = "94f38103c984f89cf77c402f2a68dbd870f8165f"
uuid = "3bb67fe8-82b1-5028-8e26-92a6c54297fa"
version = "0.9.11"

[[Tricks]]
git-tree-sha1 = "6bac775f2d42a611cdfcd1fb217ee719630c4175"
uuid = "410a4b4d-49e4-4fbc-ab6d-cb71b17b3775"
version = "0.1.6"

[[URIs]]
git-tree-sha1 = "ac00576f90d8a259f2c9d823e91d1de3fd44d348"
uuid = "5c2747f8-b7ea-4ff2-ba2e-563bfd36b1d4"
version = "1.4.1"

[[UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"

[[UnPack]]
git-tree-sha1 = "387c1f73762231e86e0c9c5443ce3b4a0a9a0c2b"
uuid = "3a884ed6-31ef-47d7-9d2a-63182c4928ed"
version = "1.0.2"

[[Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"

[[UnicodeFun]]
deps = ["REPL"]
git-tree-sha1 = "53915e50200959667e78a92a418594b428dffddf"
uuid = "1cfade01-22cf-5700-b092-accc4b62d6e1"
version = "0.4.1"

[[Unitful]]
deps = ["ConstructionBase", "Dates", "LinearAlgebra", "Random"]
git-tree-sha1 = "d670a70dd3cdbe1c1186f2f17c9a68a7ec24838c"
uuid = "1986cc42-f94f-5a68-af5c-568840ba703d"
version = "1.12.2"

[[Unzip]]
git-tree-sha1 = "ca0969166a028236229f63514992fc073799bb78"
uuid = "41fe7b60-77ed-43a1-b4f0-825fd5a5650d"
version = "0.2.0"

[[Wayland_jll]]
deps = ["Artifacts", "Expat_jll", "JLLWrappers", "Libdl", "Libffi_jll", "Pkg", "XML2_jll"]
git-tree-sha1 = "ed8d92d9774b077c53e1da50fd81a36af3744c1c"
uuid = "a2964d1f-97da-50d4-b82a-358c7fce9d89"
version = "1.21.0+0"

[[Wayland_protocols_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "4528479aa01ee1b3b4cd0e6faef0e04cf16466da"
uuid = "2381bf8a-dfd0-557d-9999-79630e7b1b91"
version = "1.25.0+0"

[[WeakRefStrings]]
deps = ["DataAPI", "InlineStrings", "Parsers"]
git-tree-sha1 = "b1be2855ed9ed8eac54e5caff2afcdb442d52c23"
uuid = "ea10d353-3f73-51f8-a26c-33c1cb351aa5"
version = "1.4.2"

[[WoodburyMatrices]]
deps = ["LinearAlgebra", "SparseArrays"]
git-tree-sha1 = "de67fa59e33ad156a590055375a30b23c40299d3"
uuid = "efce3f68-66dc-5838-9240-27a6d6f5f9b6"
version = "0.5.5"

[[XML2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libiconv_jll", "Pkg", "Zlib_jll"]
git-tree-sha1 = "93c41695bc1c08c46c5899f4fe06d6ead504bb73"
uuid = "02c8fc9c-b97f-50b9-bbe4-9be30ff0a78a"
version = "2.10.3+0"

[[XSLT_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libgcrypt_jll", "Libgpg_error_jll", "Libiconv_jll", "Pkg", "XML2_jll", "Zlib_jll"]
git-tree-sha1 = "91844873c4085240b95e795f692c4cec4d805f8a"
uuid = "aed1982a-8fda-507f-9586-7b0439959a61"
version = "1.1.34+0"

[[Xorg_libX11_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libxcb_jll", "Xorg_xtrans_jll"]
git-tree-sha1 = "5be649d550f3f4b95308bf0183b82e2582876527"
uuid = "4f6342f7-b3d2-589e-9d20-edeb45f2b2bc"
version = "1.6.9+4"

[[Xorg_libXau_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "4e490d5c960c314f33885790ed410ff3a94ce67e"
uuid = "0c0b7dd1-d40b-584c-a123-a41640f87eec"
version = "1.0.9+4"

[[Xorg_libXcursor_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libXfixes_jll", "Xorg_libXrender_jll"]
git-tree-sha1 = "12e0eb3bc634fa2080c1c37fccf56f7c22989afd"
uuid = "935fb764-8cf2-53bf-bb30-45bb1f8bf724"
version = "1.2.0+4"

[[Xorg_libXdmcp_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "4fe47bd2247248125c428978740e18a681372dd4"
uuid = "a3789734-cfe1-5b06-b2d0-1dd0d9d62d05"
version = "1.1.3+4"

[[Xorg_libXext_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll"]
git-tree-sha1 = "b7c0aa8c376b31e4852b360222848637f481f8c3"
uuid = "1082639a-0dae-5f34-9b06-72781eeb8cb3"
version = "1.3.4+4"

[[Xorg_libXfixes_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll"]
git-tree-sha1 = "0e0dc7431e7a0587559f9294aeec269471c991a4"
uuid = "d091e8ba-531a-589c-9de9-94069b037ed8"
version = "5.0.3+4"

[[Xorg_libXi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libXext_jll", "Xorg_libXfixes_jll"]
git-tree-sha1 = "89b52bc2160aadc84d707093930ef0bffa641246"
uuid = "a51aa0fd-4e3c-5386-b890-e753decda492"
version = "1.7.10+4"

[[Xorg_libXinerama_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libXext_jll"]
git-tree-sha1 = "26be8b1c342929259317d8b9f7b53bf2bb73b123"
uuid = "d1454406-59df-5ea1-beac-c340f2130bc3"
version = "1.1.4+4"

[[Xorg_libXrandr_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libXext_jll", "Xorg_libXrender_jll"]
git-tree-sha1 = "34cea83cb726fb58f325887bf0612c6b3fb17631"
uuid = "ec84b674-ba8e-5d96-8ba1-2a689ba10484"
version = "1.5.2+4"

[[Xorg_libXrender_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll"]
git-tree-sha1 = "19560f30fd49f4d4efbe7002a1037f8c43d43b96"
uuid = "ea2f1a96-1ddc-540d-b46f-429655e07cfa"
version = "0.9.10+4"

[[Xorg_libpthread_stubs_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "6783737e45d3c59a4a4c4091f5f88cdcf0908cbb"
uuid = "14d82f49-176c-5ed1-bb49-ad3f5cbd8c74"
version = "0.1.0+3"

[[Xorg_libxcb_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "XSLT_jll", "Xorg_libXau_jll", "Xorg_libXdmcp_jll", "Xorg_libpthread_stubs_jll"]
git-tree-sha1 = "daf17f441228e7a3833846cd048892861cff16d6"
uuid = "c7cfdc94-dc32-55de-ac96-5a1b8d977c5b"
version = "1.13.0+3"

[[Xorg_libxkbfile_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll"]
git-tree-sha1 = "926af861744212db0eb001d9e40b5d16292080b2"
uuid = "cc61e674-0454-545c-8b26-ed2c68acab7a"
version = "1.1.0+4"

[[Xorg_xcb_util_image_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xcb_util_jll"]
git-tree-sha1 = "0fab0a40349ba1cba2c1da699243396ff8e94b97"
uuid = "12413925-8142-5f55-bb0e-6d7ca50bb09b"
version = "0.4.0+1"

[[Xorg_xcb_util_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libxcb_jll"]
git-tree-sha1 = "e7fd7b2881fa2eaa72717420894d3938177862d1"
uuid = "2def613f-5ad1-5310-b15b-b15d46f528f5"
version = "0.4.0+1"

[[Xorg_xcb_util_keysyms_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xcb_util_jll"]
git-tree-sha1 = "d1151e2c45a544f32441a567d1690e701ec89b00"
uuid = "975044d2-76e6-5fbe-bf08-97ce7c6574c7"
version = "0.4.0+1"

[[Xorg_xcb_util_renderutil_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xcb_util_jll"]
git-tree-sha1 = "dfd7a8f38d4613b6a575253b3174dd991ca6183e"
uuid = "0d47668e-0667-5a69-a72c-f761630bfb7e"
version = "0.3.9+1"

[[Xorg_xcb_util_wm_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xcb_util_jll"]
git-tree-sha1 = "e78d10aab01a4a154142c5006ed44fd9e8e31b67"
uuid = "c22f9ab0-d5fe-5066-847c-f4bb1cd4e361"
version = "0.4.1+1"

[[Xorg_xkbcomp_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libxkbfile_jll"]
git-tree-sha1 = "4bcbf660f6c2e714f87e960a171b119d06ee163b"
uuid = "35661453-b289-5fab-8a00-3d9160c6a3a4"
version = "1.4.2+4"

[[Xorg_xkeyboard_config_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xkbcomp_jll"]
git-tree-sha1 = "5c8424f8a67c3f2209646d4425f3d415fee5931d"
uuid = "33bec58e-1273-512f-9401-5d533626f822"
version = "2.27.0+4"

[[Xorg_xtrans_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "79c31e7844f6ecf779705fbc12146eb190b7d845"
uuid = "c5fb5394-a638-5e4d-96e5-b29de1b5cf10"
version = "1.4.0+3"

[[Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"
version = "1.2.12+3"

[[Zstd_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "e45044cd873ded54b6a5bac0eb5c971392cf1927"
uuid = "3161d3a3-bdf6-5164-811a-617609db77b4"
version = "1.5.2+0"

[[ZygoteRules]]
deps = ["MacroTools"]
git-tree-sha1 = "8c1a8e4dfacb1fd631745552c8db35d0deb09ea0"
uuid = "700de1a5-db45-46bc-99cf-38207098b444"
version = "0.2.2"

[[fzf_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "868e669ccb12ba16eaf50cb2957ee2ff61261c56"
uuid = "214eeab7-80f7-51ab-84ad-2988db7cef09"
version = "0.29.0+0"

[[libaom_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "3a2ea60308f0996d26f1e5354e10c24e9ef905d4"
uuid = "a4ae2306-e953-59d6-aa16-d00cac43593b"
version = "3.4.0+0"

[[libass_jll]]
deps = ["Artifacts", "Bzip2_jll", "FreeType2_jll", "FriBidi_jll", "HarfBuzz_jll", "JLLWrappers", "Libdl", "Pkg", "Zlib_jll"]
git-tree-sha1 = "5982a94fcba20f02f42ace44b9894ee2b140fe47"
uuid = "0ac62f75-1d6f-5e53-bd7c-93b484bb37c0"
version = "0.15.1+0"

[[libblastrampoline_jll]]
deps = ["Artifacts", "Libdl", "OpenBLAS_jll"]
uuid = "8e850b90-86db-534c-a0d3-1478176c7d93"
version = "5.1.1+0"

[[libfdk_aac_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "daacc84a041563f965be61859a36e17c4e4fcd55"
uuid = "f638f0a6-7fb0-5443-88ba-1cc74229b280"
version = "2.0.2+0"

[[libpng_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Zlib_jll"]
git-tree-sha1 = "94d180a6d2b5e55e447e2d27a29ed04fe79eb30c"
uuid = "b53b4c65-9356-5827-b1ea-8c7a1a84506f"
version = "1.6.38+0"

[[libvorbis_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Ogg_jll", "Pkg"]
git-tree-sha1 = "b910cb81ef3fe6e78bf6acee440bda86fd6ae00c"
uuid = "f27f6e37-5d2b-51aa-960f-b287f2bc3b7a"
version = "1.3.7+1"

[[nghttp2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"
version = "1.48.0+0"

[[p7zip_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "3f19e933-33d8-53b3-aaab-bd5110c3b7a0"
version = "17.4.0+0"

[[x264_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "4fea590b89e6ec504593146bf8b988b2c00922b2"
uuid = "1270edf5-f2f9-52d2-97e9-ab00b5d0237a"
version = "2021.5.5+0"

[[x265_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "ee567a171cce03570d77ad3a43e90218e38937a9"
uuid = "dfaa095f-4041-5dcd-9319-2fabd8486b76"
version = "3.5.0+0"

[[xkbcommon_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Wayland_jll", "Wayland_protocols_jll", "Xorg_libxcb_jll", "Xorg_xkeyboard_config_jll"]
git-tree-sha1 = "9ebfc140cc56e8c2156a15ceac2f0302e327ac0a"
uuid = "d8fb68d0-12a3-5cfd-a85a-d49703b185fd"
version = "1.4.1+0"
"""

# ╔═╡ Cell order:
# ╟─b0dd2638-2e67-4f29-899a-4dba8d25c960
# ╟─a1638e89-30b4-41e6-ae6c-9b0cd0c92fcd
# ╟─604a6a0b-0fc4-47e4-9dc1-dbb56106852b
# ╟─41e825fa-43e2-4b33-9e25-98145cb4eb63
# ╟─d2a72eda-685e-4033-acc4-d384f2816e80
# ╟─d8ac806d-99b8-4a69-a31d-a92711b274af
# ╟─1d84e220-7bca-489b-83d8-87fe26398435
# ╟─1d5df523-879e-4398-849e-d4b21003dd12
# ╟─2b531ea8-87eb-4a63-aabc-e7520f18a893
# ╟─59304232-cf0f-47ec-b993-86afcd2cc227
# ╟─5473f343-4dd5-4aef-88c9-4287a876d7f9
# ╟─fc00184b-9bcc-4833-9fc8-49ef2efbd3af
# ╟─ba54f82c-9e6c-409d-86bd-a85cc4609357
# ╟─38129859-df5e-4faa-a75c-8304b2bed55b
# ╠═0a889312-d965-11eb-28e0-a72a1379850a
# ╟─56bf3614-092d-4891-b1aa-7b2c5e1ddcbc
# ╟─4bbffe2c-0520-4e7b-bf38-0857454336ef
# ╠═35641e0f-537c-476a-86bd-d690d0989736
# ╟─cb8c4c09-6783-42c1-b114-d2a20dbfa3f7
# ╟─bcc5fa0f-7595-4a21-a057-1cbabf94a049
# ╟─d76ec9fb-77f4-4a14-afb2-713cbd03ffab
# ╠═ba5fb3fa-b9f8-43c3-881c-0dc26c399b70
# ╟─5862c0fe-ff2c-45c9-aef4-ab0635442ee5
# ╠═ac71b40d-5f79-4881-9086-c71c89077499
# ╟─fe54d279-6d03-4892-9c0f-9dccb42b77a1
# ╠═daef9e51-08b5-4ab3-946a-703052ef1a34
# ╟─3c300825-ef08-4e5d-ab29-9264bb8e1024
# ╠═5b99fcb5-c3e1-4a01-84e6-334b26562301
# ╟─c9f07270-f1ce-4b1b-b8b0-a4ab53440366
# ╟─7679b0ba-5a04-4af3-9f58-80644da08f9e
# ╠═202247cd-7a29-4f24-a5f9-831badce334f
# ╟─55292329-200f-4cf3-bb1d-e4cff6def15b
# ╠═dd802a34-6bf2-4395-95e6-1cacf33834c8
# ╠═e533c789-73e5-4843-b58e-9b00c950aa0b
# ╟─d4c9bb7f-7e92-4b42-af59-d74d7db3298c
# ╟─fa2265a6-3bf5-4b29-9fcb-271d1215ea62
# ╠═9a40e63d-bcb0-47d9-9daa-f98e6b2d90d7
# ╟─4e82b6b7-abb8-4248-ad92-65e082c2eedc
# ╠═8875b4e6-95ca-4c31-a6c5-70fd7193f5a5
# ╟─77d30cef-dc91-4db1-886f-15b4787f1ec7
# ╠═fa03c28c-5c2a-4764-9260-6acd9b5ec5a3
# ╟─da45685f-db9b-4c8a-a62b-0bc9cfc04311
# ╠═d3074335-0625-402a-b4d3-6ae65c8cd168
# ╟─4530a0c3-c05a-46ab-9510-aeac2d56da1a
# ╟─8a231ad0-e2a9-423a-b1b0-e600e0e3aac2
# ╠═59dd2d1e-78e2-431d-ad92-a7368b8e54ce
# ╟─fdc77b5c-5a56-43bc-b304-89f1f064c9a5
# ╟─5d8b2518-66a5-4ab2-992b-b80b98d1a498
# ╟─d9114195-74b2-4c2d-bc0a-151fa37bc46a
# ╠═4d57848c-a2e7-4d5a-b848-f3822437da6a
# ╟─67ce45d2-96e7-470b-8f36-b062b5a51d7d
# ╟─c9ed1499-4bc6-45d6-921f-9e023fe28736
# ╠═be2300ea-50a6-42b3-bc3b-3e65e01b3203
# ╟─1d63cee3-0d5d-497d-b019-ce9c8865c4d4
# ╟─c0c6a6b9-407d-4861-bb27-6e150ee3381d
# ╟─a508b27d-4a2d-4453-87e8-c6d330f65b6d
# ╟─d4521113-4a5c-4154-877f-7228885e0ac2
# ╟─b4ac7dc7-6000-40c0-a081-c39bc3d286d9
# ╠═25379449-9118-4d18-8688-1bedccd454b9
# ╟─e648c42a-9ebc-46f0-bdff-55d74a284009
# ╟─2d338a77-33ee-4256-a728-fafb7d15c13a
# ╟─ebce3a87-1fd8-4f63-a7ac-c97476c15323
# ╟─eddb1866-9242-485a-9971-a0b1043d0eb7
# ╟─d444fc11-9113-41bb-86a8-792feabafe7f
# ╟─66364ec2-d852-4d02-940f-feafd7deb53d
# ╟─2dabc2fc-45f6-4454-855d-555f3eacefdf
# ╟─488c6914-0a09-475f-870b-6148dc6dadb3
# ╟─0268bff0-7ccd-404f-8424-78444885fb4a
# ╠═f0d1a772-2b1d-4feb-8d52-b9dbf29b3f45
# ╟─75b087ff-fb90-4a79-b95b-678157f4046e
# ╟─c9cb1b8e-bb4a-4f74-9e35-96ad9530413e
# ╟─9a95c55a-8e44-42d3-a52e-2f18d670811b
# ╠═ee1d8881-4dce-45d3-95fa-9bb33819ebe9
# ╟─a6407c69-ac39-4819-9429-239f43a5dc63
# ╟─56a1aa18-0134-4e4f-a6cc-3662316284dc
# ╟─3db99f8c-f238-427c-8239-19a7d94401b7
# ╠═361bbe46-bf9a-4a6c-834f-5a0660f9a0e6
# ╠═e0267345-df37-410b-bcca-218e35388f87
# ╟─17c15ad0-c7b9-4a6e-9375-4bcc1f84a517
# ╟─246063c6-d2ca-4796-88c5-fa1489e6381b
# ╟─e14f6526-c5e3-4c17-896e-2983c030f5e9
# ╟─98508321-fb4b-4076-9c95-0d38f63303b8
# ╟─8f76c559-ef89-46c0-a792-75a1de96f6e5
# ╟─f7ad9931-1d92-4d08-a0ee-9393dd524f92
# ╟─25f7c2a3-a8a7-441e-8da1-b311fd355867
# ╠═c08308c9-eade-4209-b755-2415542e542a
# ╟─cffb9e34-c2ab-40c2-8006-e1fd934fd066
# ╟─d5a447b4-2d22-4466-b89f-de859ed9f09e
# ╟─22a18398-a6ac-4229-8a52-e984315bb699
# ╟─c91b9d30-b8e0-457a-a958-2d5f60451b78
# ╟─9f2ece88-dbc7-495e-9ca5-6518af58caf8
# ╟─cc9fb021-35f9-4183-b992-40d82a5c1d2b
# ╠═325084cb-b233-4a63-8f8c-7ba32b7e8d43
# ╟─b505808f-6a05-4f2a-b755-201065b9c5f5
# ╟─7a209d2b-06b8-4177-a728-14a6b7e364ed
# ╟─dd59eee8-2265-4487-a875-a09aca2d9cb0
# ╟─e552da86-a408-4b3f-a0b6-eb9e9702ddc5
# ╟─bd6d5348-56e9-45d0-8770-0499d437b0a6
# ╠═2dbc5948-3c9e-4a93-9919-702fab2a992d
# ╟─1a9b44b4-415f-47aa-acae-dbef7c9af54a
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002

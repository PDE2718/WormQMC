# abstract type BH_Parameters end
@kwdef struct BH_Stick <: BH_Parameters
    nmax::StateType = 1 # nmax must be implemented
    Lx::IndexType = 0 # the size should also be implemented
    Ly::IndexType = 0
    Jp::f64 = 1.0 # hopping in the parallel direction
    Jq::f64 = 1.0 # hopping in the perpendicular direction
    R::f64 = 1.0 # strength of rotation
    U::f64 = 0.0 # on site repulsion, can be zero if nmax==1
    V::f64 = 1.0 # off site repulsion, set to a large value for shaped hard core
    μ::f64 = 0.0 # chemical potential
end
N_sublatt(::Type{BH_Stick}) = 2
N_wldim(::Type{BH_Stick})::Int = 3
N_nbs(::Type{BH_Stick})::Int = 13
N_hops(::Type{BH_Stick})::Int = 5

function get_nbs(H::BH_Stick, i::Integer)::NTuple{13,Int}
    @inbounds begin
        Lx = Int(H.Lx)
        Ly = Int(H.Ly)
        x0, y0, s0 = CartesianIndices((Lx, Ly, 2))[i] |> Tuple
        x₋ = mod1(x0 - 1, Lx)
        x₊ = mod1(x0 + 1, Lx)
        y₋ = mod1(y0 - 1, Ly)
        y₊ = mod1(y0 + 1, Ly)
        C = LinearIndices((Lx, Ly, 2))
        if s0 == 1
            sp = 2
            r₋ = mod1(x0 - 2, Lx)
            r₊ = mod1(x0 + 2, Lx)
            return (C[x0, y0, sp],
                C[x₋, y0, s0], C[x₊, y0, s0],
                C[r₋, y0, s0], C[r₊, y0, s0],
                C[x₋, y₋, sp], C[x₋, y0, sp], C[x₋, y₊, sp],
                C[x0, y₋, sp], C[x0, y₊, sp],
                C[x₊, y₋, sp], C[x₊, y0, sp], C[x₊, y₊, sp]
            )
        else
            sp = 1
            r₋ = mod1(y0 - 2, Ly)
            r₊ = mod1(y0 + 2, Ly)
            return (C[x0, y0, sp],
                C[x0, y₋, s0], C[x0, y₊, s0],
                C[x0, r₋, s0], C[x0, r₊, s0],
                C[x₋, y₋, sp], C[x₋, y0, sp], C[x₋, y₊, sp],
                C[x0, y₋, sp], C[x0, y₊, sp],
                C[x₊, y₋, sp], C[x₊, y0, sp], C[x₊, y₊, sp]
            )
        end
    end
end
function get_hops(H::BH_Stick, i::Integer)::NTuple{5,Int}
    @inbounds begin
        Lx = Int(H.Lx)
        Ly = Int(H.Ly)
        x0, y0, s0 = CartesianIndices((Lx, Ly, 2))[i] |> Tuple
        C = LinearIndices((Lx, Ly, 2))
        if s0 == 1
            return (
                C[x0, y0, 2], # R
                C[mod1(x0 - 1, Lx), y0, 1], C[mod1(x0 + 1, Lx), y0, 1], # Jp
                C[x0, mod1(y0 - 1, Ly), 1], C[x0, mod1(y0 + 1, Ly), 1], # Jq
            )
        else
            return (
                C[x0, y0, 1], 
                C[mod1(x0 - 1, Lx), y0, 2], C[mod1(x0 + 1, Lx), y0, 2], # Jq
                C[x0, mod1(y0 - 1, Ly), 2], C[x0, mod1(y0 + 1, Ly), 2], # Jp
            )
        end
    end
end
function diagE(H::BH_Stick, i, ni::StateType, njs::NTuple{13,StateType})::f64
    return 0.5 * H.U * ni * (ni - 1) - H.μ * ni + H.V * ni * sum(njs)
end

function bond_weight(H::BH_Stick, i::Integer, j::Integer)::f64
    lattice = CartesianIndices((H.Lx, H.Ly, 2))
    xi, yi, si = Tuple(lattice[i])
    xj, yj, sj = Tuple(lattice[j])
    if si == sj == 1
        return (xi ≠ xj) ? H.Jp : H.Jq
    elseif si == sj == 2
        return (yi ≠ yj) ? H.Jp : H.Jq
    else
        return H.R
    end
end

function site_diff(H::BH_Stick, i, j)::CartesianIndex{4}
    lattice = CartesianIndices((H.Lx, H.Ly, 2))
    xi, yi, si = Tuple(lattice[i])
    xj, yj, sj = Tuple(lattice[j])
    dx = mod1(xj - xi + 1, H.Lx)
    dy = mod1(yj - yi + 1, H.Ly)
    return CartesianIndex(dx, dy, si, sj)
end

Wsheet(β::f64, H::BH_Stick) = Wsheet(β, zeros(StateType, H.Lx, H.Ly, 2))

function simple_measure!(m::SimpleMeasure, x::Wsheet{3}, H::BH_Stick,
    bond_buffer::Wline)::Nothing
    U = μ = V = 0.0
    N₁ = N₂ = 0
    for (i, c) ∈ enumerate(CartesianIndices(x.wl))
        li::Wline = x[i]
        U, μ = (U, μ) .+ measure_site(li, H.U, H.μ)
        for nb ∈ get_nbs(H, i)
            if nb < i
                V += measure_bond(li, x[nb], H.V, bond_buffer)
            end
        end
        ni = li[end].n_L
        if ni > 0
            if c[3] == 1
                N₁ += ni
            else #if c[3] == 2
                N₂ += ni
            end
        end
    end
    # Wx, Wy, NKx, NKy = winding_number(x, H)
    Wx = Wy = NKx = NKy = NKz = 0
    Wx = Wy = 0
    for i ∈ eachindex(x)
        for e::Element ∈ x[i]::Wline
            if e.op == b_
                @assert e.i == i
                hops = get_hops(H, i)
                j = Int(e.j)
                if j == hops[1]
                    NKz += 1
                elseif j == hops[2]
                    Wx -= 1
                    NKx += 1
                elseif j == hops[3]
                    Wx += 1
                    NKx += 1
                elseif j == hops[4]
                    Wy -= 1
                    NKy += 1
                elseif j == hops[5]
                    Wy += 1
                    NKy += 1
                else
                    error("illegal operator")
                end
            end
        end
    end
    @assert Wx % H.Lx == Wy % H.Ly == 0
    Wx ÷= H.Lx
    Wy ÷= H.Ly
    Kx = -NKx / x.β
    Ky = -NKy / x.β
    Kz = -NKz / x.β
    K = Kx + Ky + Kz
    N = N₁ + N₂
    Δ² = abs2(N₁ - N₂)
    E = U + μ + V + K
    Wx² = abs2(Wx)
    Wy² = abs2(Wy)
    m.props = m.props .+ (
        E,
        N, abs2(N), N₁, abs2(N₁), N₂, abs2(N₂),
        Δ², K, U, μ, V, 
        Kx, Ky, Kz, Wx², Wy²
    )
    m.n_measure += 1
    return nothing
end

function simple_measure_names(::BH_Stick)
    return (:E,
        :N, :N², :N₁, :N₁², :N₂, :N₂², 
        :Δ², :K, :U, :μ, :V, 
        :Kx, :Ky, :Kz, :Wx², :Wy²
    )
end
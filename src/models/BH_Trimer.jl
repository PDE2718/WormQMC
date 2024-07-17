abstract type BH_Parameters end
@kwdef struct BH_Trimer <: BH_Parameters
    nmax::StateType = 1 # nmax must be implemented
    Lx::IndexType = 0 # the size should also be implemented
    Ly::IndexType = 0
    J1::f64 = 1.0 # other parameters
    J2::f64 = 1.0 # other parameters
    U::f64 = 0.0 # on site repulsion, can be zero if nmax==1
    V::f64 = 1.0 # off site repulsion, set to a large value for shaped hard core
    μ::f64 = 0.0 # chemical potential
end
N_sublatt(::Type{BH_Trimer}) = 2
N_wldim(::Type{BH_Trimer})::Int = 3
N_nbs(::Type{BH_Trimer})::Int = 13
N_hops(::Type{BH_Trimer})::Int = 3

function get_nbs(H::BH_Trimer, i::Integer)::NTuple{13,Int}
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
function get_hops(H::BH_Trimer, i::Integer)::NTuple{3, Int}
    @inbounds begin
        Lx = Int(H.Lx)
        Ly = Int(H.Ly)
        x0, y0, s0 = CartesianIndices((Lx, Ly, 2))[i] |> Tuple
        C = LinearIndices((Lx, Ly, 2))
        if s0 == 1
            return (C[x0, y0, 2], C[mod1(x0 - 1, Lx), y0, 1], C[mod1(x0 + 1, Lx), y0, 1])
        else
            return (C[x0, y0, 1], C[x0, mod1(y0 - 1, Ly), 2], C[x0, mod1(y0 + 1, Ly), 2])
        end
    end
end
function diagE(H::BH_Trimer, ni::StateType, njs::NTuple{13,StateType})::f64
    return 0.5 * H.U * ni * (ni - 1) - H.μ * ni + H.V * ni * sum(njs)
end
# function bond_weight(H::BH_, i::Integer, j::Integer)::f64
#     N = H.Lx * H.Ly
#     return (i > N) ⊻ (j > N) ? H.J2 : H.J1
# end
# function bond_weight(H::BH_Trimer, i::Integer, j::Integer)::f64
#     lattice = CartesianIndices((H.Lx, H.Ly, 2))
#     xi, yi, si = lattice[i]
#     xj, yj, sj = lattice[j]
#     if si == sj
#         if si == 1 && yi==yj && abs(xj-xi)==1
#             return J1
#         elseif si == 2 && xi==xj && abs(yj-yi)==1
#             return J1
#         else
#             return 0.0
#         end
#     else
#         if xi == xj && yi == yj
#             return H.J2
#         else
#             return 0.
#         end
#     end
#     return lattice[i][3] == lattice[j][3] ? H.J2 : H.J1
# end
function bond_weight(H::BH_Trimer, i::Integer, j::Integer)::f64
    lattice = CartesianIndices((H.Lx, H.Ly, 2))
    return lattice[i][3] == lattice[j][3] ? H.J2 : H.J1
end

function site_diff(H::BH_Trimer, i, j)::CartesianIndex{4}
    lattice = CartesianIndices((H.Lx, H.Ly, 2))
    xi, yi, si = Tuple(lattice[i])
    xj, yj, sj = Tuple(lattice[j])
    dx = mod1(xj - xi + 1, H.Lx)
    dy = mod1(yj - yi + 1, H.Ly)
    return CartesianIndex(dx, dy, si, sj)
end

Wsheet(β::f64, H::BH_Trimer) = Wsheet(β, zeros(StateType, H.Lx, H.Ly, 2))

## Measurement for the winding_number
function winding_number(x::Wsheet{3}, H::BH_Trimer)::NTuple{2,Int}
    Wx::Int = Wy::Int = 0
    N0::Int = H.Lx * H.Ly
    for i ∈ eachindex(x)
        for e::Element ∈ x[i]::Wline
            if e.op == b_
                @assert e.i == i
                hops = get_hops(H, i)
                j = Int(e.j)
                if j == hops[1]
                    nothing
                elseif j == hops[2]
                    if i ≤ N0
                        Wx -= 1
                    else
                        Wy -= 1
                    end
                elseif j == hops[3]
                    if i ≤ N0
                        Wx += 1
                    else
                        Wy += 1
                    end
                else
                    error("illegal operator")
                end
                # Wy = Wy - (dir == 1) + (dir == 2)
                # Wx = Wx - (dir == 3) + (dir == 4)
            end
        end
    end
    @assert Wx % H.Lx == Wy % H.Ly == 0
    WxWy = (Wx ÷ H.Lx, Wy ÷ H.Ly)
    return WxWy
end

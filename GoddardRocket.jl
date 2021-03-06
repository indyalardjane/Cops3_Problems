using ADNLPModels, NLPModels, NLPModelsIpopt, DataFrames, LinearAlgebra, Distances, SolverCore, Plots

function goddardrocket(; n::Int = default_nvar, type::Val{T} = Val(Float64), kwargs...) where {T}

    # Initialisation
    # Constants
    h_0 = T(1) # height initialization   
    v_0 = T(0) # speed initialization   
    m_0 = T(1) # mass initialization  
    g_0 = T(1) # gravity initialization

    # Parameters

    h_c = T(500) # Used for drag
    v_c = T(620) # Used for drag
    m_c = T(0.6) # Fraction of initial mass left at end

    c = T(1/2 * (g_0*h_0)^2)        # Thrust-to-fuel mass
    m_f = T(m_0 * m_c)              # final mass
    T_max = T(3.5 * g_0 * m_0)      # maximal rocket thrust
    D_c = T(1/2 * v_c * (m_0/g_0))  # Drag scaling

    function Objective(X :: Vector{S}) where {S}

        v = zeros(S, n)  # velocity vector
        h = zeros(S, n)  # height vector
        g = zeros(S, n)  # gravity vector
        m = zeros(S, n)  # mass vector
        D = zeros(S, n)  # drag vector

        v[1] = S(v_0)          # velocity vector initialization
        h[1] = S(h_0)          # height vector initialization
        g[1] = S(g_0)          # gravity vector initialization
        m[1] = S(m_0)          # mass vector initialization
        D[1] = S(D_c*(v_0^2))  # drag vector initialization
        for k=2:n
            m[k] = S(m[k - 1] - Δt * X[k - 1] / c)                                  # update mass vector   
            v[k] = S(v[k - 1] + Δt *((X[k - 1] - D[k - 1]) / m[k - 1] - g[k - 1]))  # update speed vector
            h[k] = S(h[k - 1] + Δt * v[k - 1])                                      # update height vector
            D[k] = S(D_c*(v[k]^2)*exp(-h_c*(h[k]-h_0)/h_0))                         # update drag vector
            g[k] = S(g_0*(h_0/h[k])^2)                                              # update gravity vector
        end
        opt = -h[end]
        return opt

    end

    function constraints(X :: Vector{S}) where {S}

        v = zeros(S, n)
        h = zeros(S, n)
        g = zeros(S, n)
        m = zeros(S, n)
        D = zeros(S, n)

        v[1] = S(v_0)          # velocity vector initialization
        h[1] = S(h_0)          # height vector initialization
        g[1] = S(g_0)          # gravity vector initialization
        m[1] = S(m_0)          # mass vector initialization
        D[1] = S(D_c*(v_0^2))  # drag vector initialization
        for k=2:n
            m[k] = S(m[k - 1] - Δt * X[k - 1] / c)
            v[k] = S(v[k - 1] + Δt *((X[k - 1] - D[k - 1]) / m[k - 1] - g[k - 1]))
            h[k] = S(h[k - 1] + Δt * v[k - 1])
            D[k] = S(D_c*(v[k]^2)*exp(-h_c*(h[k]-h_0)/h_0))
        end
        constraints = vcat(v, h .- h[1], m .- m_f)  # constraint vector for velocity, height, mass, thrust
        return constraints

    end
    Δt  = T(1/(n-1))  # Indya, ce n'est pas 1/(n-1) à la place ?
    X0 = T_max/2 * ones(T, n) 
    lvar = zeros(T, n) 
    uvar =  T_max/2 * ones(T, n) 
    lcon = zeros(T, 3 * n)
    ucon = T[i ≤ 2n ? T(Inf) : ( T(m_0 - m_f)) for i=1:3n]

    nlp = ADNLPModel(Objective, X0, lvar, uvar, constraints, lcon, ucon)
    return nlp
end


default_nvar = 10
nlp = goddardrocket()
x = rand(10)
f_x = obj(nlp, x)
c_x = cons(nlp, x)
grad_x = grad(nlp, x)
hess_x = hess(nlp, x)
jac_x = jac(nlp, x)

# t = [i * 1/(default_nvar-1) for i = 0:default_nvar-1]
output = ipopt(nlp)
print(output.solution)
plot(output.solution)

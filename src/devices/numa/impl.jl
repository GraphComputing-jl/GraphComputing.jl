using NumaAllocators

"""
    NumaNode <: AbstractCPU

Representation of a specific CPU that code can run on. Implements the [`AbstractDevice`](@ref) interface.
"""
mutable struct NumaNode <: AbstractCPU
    numaId::UInt16
    threads::UInt16
    cacheStrategy::CacheStrategy
    FLOPS::Float64
    id::UUID
end

push!(DEVICE_TYPES, NumaNode)

CACHE_STRATEGIES[NumaNode] = [LocalVariables()]

default_strategy(::Type{T}) where {T<:NumaNode} = LocalVariables()

function measure_device!(device::NumaNode; verbose::Bool)
    verbose && @info "Measuring Numa Node $(device.numaId)"

    # TODO implement
    return nothing
end

"""
    get_devices(deviceType::Type{T}; verbose::Bool) where {T <: NumaNode}

Return a Vector of [`NumaNode`](@ref)s available on the current machine. If `verbose` is true, print some additional information.
"""
function get_devices(deviceType::Type{T}; verbose::Bool=false) where {T<:NumaNode}
    devices = Vector{AbstractDevice}()
    noNumaNodes = highest_numa_node()

    verbose && @info "Found $(noNumaNodes + 1) NUMA nodes"

    for i in 0:noNumaNodes
        push!(devices, NumaNode(i, 1, default_strategy(NumaNode), -1, UUIDs.uuid1(rng[1])))
    end

    return devices
end

"""
    gen_cache_init_code(device::NumaNode)

Generate code for initializing the [`LocalVariables`](@ref) strategy on a [`NumaNode`](@ref).
"""
function gen_cache_init_code(device::NumaNode)
    if typeof(device.cacheStrategy) <: LocalVariables
        # don't need to initialize anything
        return Expr(:block)
    elseif typeof(device.cacheStrategy) <: Dictionary
        return Meta.parse("cache_$(to_var_name(device.id)) = Dict{Symbol, Any}()")
        # TODO: sizehint?
    end

    return error(
        "Unimplemented cache strategy \"$(device.cacheStrategy)\" for device \"$(device)\""
    )
end

"""
    _gen_access_expr(device::NumaNode, ::LocalVariables, symbol::Symbol)

Interface implementation, dispatched to from [`gen_access_expr`](@ref).
"""
function _gen_access_expr(::NumaNode, ::LocalVariables, symbol::Symbol)
    # TODO rewrite these with Expr instead of quote node
    s = Symbol("data_$symbol")
    quote_node = Meta.parse(":($s)")
    return quote_node
end

"""
    _gen_access_expr(device::NumaNode, ::Dictionary, symbol::Symbol)

Interface implementation, dispatched to from [`gen_access_expr`](@ref).
"""
function _gen_access_expr(device::NumaNode, ::Dictionary, symbol::Symbol)
    # TODO rewrite these with Expr instead of quote node
    access_str = ":(cache_$(to_var_name(device.id))[:$symbol])"
    quote_node = Meta.parse(access_str)
    return quote_node
end

"""
    _gen_local_init(fc::FunctionCall, device::NumaNode, cache_strategy::LocalVariables)

Interface implementation, dispatched to from [`gen_local_init`](@ref).
"""
function _gen_local_init(fc::FunctionCall, ::NumaNode, ::LocalVariables)
    s = Symbol("data_$(fc.return_symbol)")
    quote_node = Expr(:local, s, :(::), Symbol(fc.return_type)) # TODO: figure out how to get type info for this local variable
    return quote_node
end

"""
    _gen_local_init(fc::FunctionCall, device::NumaNode, cache_strategy::Dictionary)

Interface implementation, dispatched to from [`gen_local_init`](@ref).
"""
function _gen_local_init(::FunctionCall, ::NumaNode, ::Dictionary)
    return Exp()
end

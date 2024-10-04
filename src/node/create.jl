function DataTaskNode(t::AbstractDataTask, name="")
    return DataTaskNode(
        t,
        Vector{Node}(),
        Vector{Tuple{Node,Int}}(),      # TODO this can only ever be a single child
        UUIDs.uuid1(rng[threadid()]),
        missing,
        missing,
        name,
    )
end
function ComputeTaskNode(t::AbstractComputeTask)
    return ComputeTaskNode(
        t,                              # task
        Vector{Node}(),                 # parents
        Vector{Tuple{Node,Int}}(),      # children
        UUIDs.uuid1(rng[threadid()]),   # id
        missing,                        # node reduction
        missing,                        # node split
        missing,                        # device
    )
end

Base.copy(m::Missing) = missing
Base.copy(n::ComputeTaskNode) = ComputeTaskNode(copy(task(n)))
Base.copy(n::DataTaskNode) = DataTaskNode(copy(task(n)), n.name)

"""
    make_node(t::AbstractTask)

Fallback implementation of `make_node` for an [`AbstractTask`](@ref), throwing an error.
"""
function make_node(t::AbstractTask)
    return error("Cannot make a node from this task type")
end

"""
    make_node(t::AbstractDataTask)

Construct and return a new [`DataTaskNode`](@ref) with the given task.
"""
function make_node(t::AbstractDataTask, name::String="")
    return DataTaskNode(t, name)
end

"""
    make_node(t::AbstractComputeTask)

Construct and return a new [`ComputeTaskNode`](@ref) with the given task.
"""
function make_node(t::AbstractComputeTask)
    return ComputeTaskNode(t)
end

"""
    make_edge(n1::Node, n2::Node, index::Int)

Fallback implementation of `make_edge` throwing an error. If you got this error it likely means you tried to construct an edge between two nodes of the same type.
"""
function make_edge(n1::Node, n2::Node, index::Int=0)
    return error("can only create edges from compute to data node or reverse")
end

"""
    make_edge(n1::ComputeTaskNode, n2::DataTaskNode, index::Int)

Construct and return a new [`Edge`](@ref) pointing from `n1` (child) to `n2` (parent).

The index parameter is 0 by default and is passed to the parent node as argument index for its child.
"""
function make_edge(n1::ComputeTaskNode, n2::DataTaskNode, index::Int=0)
    return Edge((n1, n2), index)
end

"""
    make_edge(n1::DataTaskNode, n2::ComputeTaskNode)

Construct and return a new [`Edge`](@ref) pointing from `n1` (child) to `n2` (parent).

The index parameter is 0 by default and is passed to the parent node as argument index for its child.
"""
function make_edge(n1::DataTaskNode, n2::ComputeTaskNode, index::Int=0)
    return Edge((n1, n2), index)
end

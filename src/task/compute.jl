using StaticArrays

"""
    get_function_call(n::Node)
    get_function_call(t::AbstractTask, device::AbstractDevice, in_symbols::AbstractVector, out_symbol::Symbol)

For a node or a task together with necessary information, return a vector of [`FunctionCall`](@ref)s for the computation of the node or task.

For ordinary compute or data tasks the vector will contain exactly one element.
"""
function get_function_call(
    t::CompTask, device::AbstractDevice, in_symbols::AbstractVector, out_symbol::Symbol
) where {CompTask<:AbstractComputeTask}
    return [FunctionCall(compute, SVector{1,Any}(t), in_symbols, out_symbol, Any, device)]
end

function get_function_call(node::ComputeTaskNode)
    @assert length(children(node)) <= children(task(node)) "node $(node) has too many children for its task: node has $(length(node.children)) versus task has $(children(task(node)))\nnode's children: $(getfield.(node.children, :children))"
    @assert !ismissing(node.device) "trying to get expression for an unscheduled ComputeTaskNode\nnode: $(node)"

    # make sure the node is sorted so the arguments keep their order
    sort_node!(node)

    if (length(node.children) <= 800)
        #only use an SVector when there are few children
        return get_function_call(
            node.task,
            node.device,
            SVector{length(node.children),Symbol}(
                Symbol.(to_var_name.(getfield.(getindex.(children(node), 1), :id)))...
            ),
            Symbol(to_var_name(node.id)),
        )
    else
        return get_function_call(
            node.task,
            node.device,
            Symbol.(to_var_name.(getfield.(getindex.(children(node), 1), :id))),
            Symbol(to_var_name(node.id)),
        )
    end
end

function get_function_call(node::DataTaskNode)
    @assert length(children(node)) == 1 "trying to call get_function_call on a data task node that has $(length(node.children)) children instead of 1"

    # TODO: dispatch to device implementations generating the copy commands
    return [
        FunctionCall(
            unpack_identity,
            SVector{0,Any}(),
            SVector{1,Symbol}(Symbol(to_var_name(first(children(node))[1].id))),
            Symbol(to_var_name(node.id)),
            Any,
            first(children(node))[1].device,
        ),
    ]
end

function get_init_function_call(node::DataTaskNode, device::AbstractDevice)
    @assert isempty(children(node)) "trying to call get_init_function_call on a data task node that is not an entry node."

    return FunctionCall(
        unpack_identity,
        SVector{0,Any}(),
        SVector{1,Symbol}(Symbol("$(to_var_name(node.id))_in")),
        Symbol(to_var_name(node.id)),
        Any,
        device,
    )
end

function result_type(fc::FunctionCall, known_res_types::Dict{Symbol,Type})
    argument_types = (
        typeof.(fc.value_arguments)..., getindex.(Ref(known_res_types), fc.arguments)...
    )
    types = Base.return_types(fc.func, argument_types)

    if length(types) > 1
        throw(
            "failure during type inference: function call $fc is type unstable, possible return types: $types",
        )
    end

    return types[1]
end

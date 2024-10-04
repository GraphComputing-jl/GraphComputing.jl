"""
    infer_types!(schedule::Vector{FunctionCall})

Infer the result type of each function call in the given schedule. Returns a dictionary with the result type for each [`Node`](@ref). This assumes that each node has only one statically inferrable return type and will throw an exceptin otherwise.
This also assumes that the given `Vector` contains a topological ordering of its nodes, such as returned by a call to [`schedule_dag`](@ref).
"""
function infer_types!(tape::Tape)
    known_result_types = Dict{Symbol,Type}()

    # the only initially known type
    known_result_types[:input] = input_type(tape.instance)

    for fc in tape.inputAssignCode
        res_type = result_type(fc, known_result_types)
        fc.return_type = res_type
        known_result_types[fc.return_symbol] = res_type
    end

    for fc in tape.schedule
        res_type = result_type(fc, known_result_types)
        fc.return_type = res_type
        known_result_types[fc.return_symbol] = res_type
    end

    return nothing
end

"""
    lower(schedule::Vector{Node}, machine::Machine)

After [`schedule_dag`](@ref) has made a schedule of nodes, this function lowers the vector of [`Node`](@ref)s into a vector of [`FunctionCall`](@ref)s.
"""
function lower(schedule::Vector{Node}, machine::Machine)
    calls = Vector{FunctionCall}()

    for node in schedule
        if (node isa DataTaskNode && length(children(node)) == 0)
            push!(calls, get_init_function_call(node, entry_device(machine)))
        else
            push!(calls, get_function_call(node)...)
        end
    end

    return calls
end

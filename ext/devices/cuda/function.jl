function ComputableDAGs.kernel(::Type{CUDAGPU}, graph::DAG, instance)
    machine = cpu_st()
    tape = ComputableDAGs.gen_tape(graph, instance, machine, context_module)

    init_caches = Expr(:block, tape.initCachesCode...)
    assign_inputs = Expr(:block, ComputableDAGs.expr_from_fc.(tape.inputAssignCode)...)
    code = Expr(:block, ComputableDAGs.expr_from_fc.(tape.computeCode)...)

    function_id = ComputableDAGs.to_var_name(UUIDs.uuid1(ComputableDAGs.rng[1]))
    res_sym = eval(
        ComputableDAGs.gen_access_expr(
            ComputableDAGs.entry_device(tape.machine), tape.outputSymbol
        ),
    )
    expr = Meta.parse(
        "function compute_$(function_id)(input_vector, output_vector, n::Int64)
            id = (blockIdx().x - 1) * blockDim().x + threadIdx().x
            if (id > n)  
                return
            end
            @inline data_input = input_vector[id]
            $(init_caches)
            $(assign_inputs)
            $code
            @inline output_vector[id] = $res_sym
            return nothing
        end"
    )

    return expr
end

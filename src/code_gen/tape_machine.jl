# TODO: do this with macros
function call_fc(
    fc::FunctionCall{VectorT,0}, cache::Dict{Symbol,Any}
) where {VectorT<:SVector{1}}
    cache[fc.return_symbol] = fc.func(cache[fc.arguments[1]])
    return nothing
end

function call_fc(
    fc::FunctionCall{VectorT,1}, cache::Dict{Symbol,Any}
) where {VectorT<:SVector{1}}
    cache[fc.return_symbol] = fc.func(fc.value_arguments[1], cache[fc.arguments[1]])
    return nothing
end

function call_fc(
    fc::FunctionCall{VectorT,0}, cache::Dict{Symbol,Any}
) where {VectorT<:SVector{2}}
    cache[fc.return_symbol] = fc.func(cache[fc.arguments[1]], cache[fc.arguments[2]])
    return nothing
end

function call_fc(
    fc::FunctionCall{VectorT,1}, cache::Dict{Symbol,Any}
) where {VectorT<:SVector{2}}
    cache[fc.return_symbol] = fc.func(
        fc.value_arguments[1], cache[fc.arguments[1]], cache[fc.arguments[2]]
    )
    return nothing
end

function call_fc(fc::FunctionCall{VectorT,1}, cache::Dict{Symbol,Any}) where {VectorT}
    cache[fc.return_symbol] = fc.func(
        fc.value_arguments[1], getindex.(Ref(cache), fc.arguments)...
    )
    return nothing
end

"""
    call_fc(fc::FunctionCall, cache::Dict{Symbol, Any})

Execute the given [`FunctionCall`](@ref) on the dictionary.

Several more specialized versions of this function exist to reduce vector unrolling work for common cases.
"""
function call_fc(fc::FunctionCall{VectorT,M}, cache::Dict{Symbol,Any}) where {VectorT,M}
    cache[fc.return_symbol] = fc.func(
        fc.value_arguments..., getindex.(Ref(cache), fc.arguments)...
    )
    return nothing
end

function expr_from_fc(fc::FunctionCall{VectorT,0}) where {VectorT}
    func_call = Expr(
        :call,
        fc.func,
        eval.(
            _gen_access_expr.(Ref(fc.device), Ref(fc.device.cacheStrategy), fc.arguments)
        )...,
    )
    access_expr = eval(gen_access_expr(fc))

    return Expr(:(=), access_expr, func_call)
end

"""
    expr_from_fc(fc::FunctionCall)

For a given function call, return an expression evaluating it.
"""
function expr_from_fc(fc::FunctionCall{VectorT,M}) where {VectorT,M}
    func_call = Expr(
        :call,
        fc.func,
        fc.value_arguments...,
        eval.(
            _gen_access_expr.(Ref(fc.device), Ref(fc.device.cacheStrategy), fc.arguments)
        )...,
    )
    access_expr = eval(gen_access_expr(fc))

    return Expr(:(=), access_expr, func_call)
end

"""
    gen_cache_init_code(machine::Machine)

For each [`AbstractDevice`](@ref) in the given [`Machine`](@ref), returning a `Vector{Expr}` doing the initialization.
"""
function gen_cache_init_code(machine::Machine)
    initialize_caches = Vector{Expr}()

    for device in machine.devices
        push!(initialize_caches, gen_cache_init_code(device))
    end

    return initialize_caches
end

"""
    gen_input_assignment_code(
        input_symbols::Dict{String, Vector{Symbol}},
        instance::AbstractProblemInstance,
        machine::Machine,
        context_module::Module
    )

Return a `Vector{Expr}` doing the input assignments from the given `problem_input` onto the `input_symbols`.
"""
function gen_input_assignment_code(
    input_symbols::Dict{String,Vector{Symbol}},
    instance,
    machine::Machine,
    context_module::Module,
)
    assign_inputs = Vector{FunctionCall}()
    for (name, symbols) in input_symbols
        # make a function for this, since we can't use anonymous functions in the FunctionCall

        for symbol in symbols
            device = entry_device(machine)

            fc = FunctionCall(
                context_module.eval(Expr(:->, :x, input_expr(instance, name, :x))),
                SVector{0,Any}(),
                SVector{1,Symbol}(:input),
                symbol,
                Nothing,
                device,
            )

            push!(assign_inputs, fc)
        end
    end

    return assign_inputs
end

"""
    gen_function_body(tape::Tape; closures_size)

Generate the function body from the given [`Tape`](@ref).

## Keyword Arguments
`closures_size`: The size of closures to generate (in lines of code). Closures introduce function barriers in the function body, preventing some optimizations by the compiler and therefore greatly reducing compile time. A value of 1 or less will disable the use of closures entirely.
"""
function gen_function_body(tape::Tape; closures_size::Int)
    if closures_size > 1
        # only need to annotate types later when using closures
        infer_types!(tape)
    end

    fc_vec = tape.schedule

    if (closures_size <= 1)
        return Expr(:block, expr_from_fc.(fc_vec)...)
    end

    closures = Vector{Expr}()
    # iterate from end to beginning
    # this helps because we can collect all undefined arguments to the closures that have to be returned somewhere earlier
    undefined_argument_symbols = Set{Symbol}()
    # the final return symbol is the return of the entire generated function, it always has to be returned
    push!(undefined_argument_symbols, eval(gen_access_expr(fc_vec[end])))

    for i in length(fc_vec):(-closures_size):1
        e = i
        b = max(i - closures_size, 1)
        code_block = fc_vec[b:e]

        # collect `local var` statements that need to exist before the closure starts
        local_inits = gen_local_init.(code_block)

        return_symbols = eval.(gen_access_expr.(code_block))

        ret_symbols_set = Set(return_symbols)
        for fc in code_block
            for arg in fc.arguments
                symbol = eval(_gen_access_expr(fc.device, fc.device.cacheStrategy, arg))

                # symbol won't be defined if it is first calculated in the closure
                # so don't add it to the arguments in this case
                if !(symbol in ret_symbols_set)
                    push!(undefined_argument_symbols, symbol)
                end
            end
        end

        intersect!(ret_symbols_set, undefined_argument_symbols)
        return_symbols = Symbol[ret_symbols_set...]

        closure = Expr(
            :block,
            Expr(
                :(=),
                Expr(:tuple, return_symbols...),
                Expr(
                    :call,                                  # call to the following closure (no arguments)
                    Expr(                                   # create the closure: () -> code block; return (locals)
                        :->,
                        :(),                                # closure arguments (none)
                        Expr(                               # actual function body of the closure
                            :block,
                            local_inits...,                 # declare local variables with type information inside the closure
                            expr_from_fc.(code_block)...,
                            Expr(:return, Expr(:tuple, return_symbols...)),
                        ),
                    ),
                ),
            ),
        )

        setdiff!(undefined_argument_symbols, ret_symbols_set)

        #=Expr(
            :macrocall,
            Symbol("@closure"),
            @__LINE__,
            Expr( <closure...> )
        )=#

        # combine to one closure call, including all the local inits and the actual call to the closure
        pushfirst!(closures, closure)
    end

    return Expr(:block, closures...)
end

"""
    gen_tape(
        graph::DAG,
        instance::AbstractProblemInstance,
        machine::Machine,
        context_module::Module,
        scheduler::AbstractScheduler = GreedyScheduler()
    )

Generate the code for a given graph. The return value is a [`Tape`](@ref).

See also: [`execute`](@ref), [`execute_tape`](@ref)
"""
function gen_tape(
    graph::DAG,
    instance,
    machine::Machine,
    context_module::Module,
    scheduler::AbstractScheduler=GreedyScheduler(),
)
    schedule = schedule_dag(scheduler, graph, machine)
    function_body = lower(schedule, machine)

    # get input symbols
    input_syms = Dict{String,Vector{Symbol}}()
    for node in get_entry_nodes(graph)
        if !haskey(input_syms, node.name)
            input_syms[node.name] = Vector{Symbol}()
        end

        push!(input_syms[node.name], Symbol("$(to_var_name(node.id))_in"))
    end

    # get outSymbol
    outSym = Symbol(to_var_name(get_exit_node(graph).id))

    init_caches = gen_cache_init_code(machine)
    assign_inputs = gen_input_assignment_code(input_syms, instance, machine, context_module)

    return Tape{input_type(instance)}(
        init_caches,
        assign_inputs,
        function_body,
        input_syms,
        outSym,
        Dict(),
        instance,
        machine,
    )
end

"""
    execute_tape(tape::Tape, input::Input) where {Input}

Execute the given tape with the given input.

For implementation reasons, this disregards the set [`CacheStrategy`](@ref) of the devices and always uses a dictionary.

!!! warning
    This is very slow and might not work. This is to be majorly revamped.
"""
function execute_tape(tape::Tape, input)
    cache = Dict{Symbol,Any}()
    cache[:input] = input
    # simply execute all the code snippets here
    @assert typeof(input) <: input_type(tape.instance) "expected tape input type to fit $(input_type(tape.instance)) but got $(typeof(input))"
    for expr in tape.initCachesCode
        @eval $expr
    end

    compute_code = tape.schedule

    for function_call in tape.inputAssignCode
        call_fc(function_call, cache)
    end
    for function_call in compute_code
        call_fc(function_call, cache)
    end

    return cache[tape.outputSymbol]
end

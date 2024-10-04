
"""
    Tape{INPUT}

TODO: update docs
- `INPUT` the input type of the problem instance

- `code::Vector{Expr}`: The julia expression containing the code for the whole graph.
- `inputSymbols::Dict{String, Vector{Symbol}}`: A dictionary of symbols mapping the names of the input nodes of the graph to the symbols their inputs should be provided on.
- `outputSymbol::Symbol`: The symbol of the final calculated value
"""
struct Tape{INPUT}
    initCachesCode::Vector{Expr}
    inputAssignCode::Vector{FunctionCall}
    schedule::Vector{FunctionCall}
    inputSymbols::Dict{String,Vector{Symbol}}
    outputSymbol::Symbol
    cache::Dict{Symbol,Any}
    instance::Any
    machine::Machine
end

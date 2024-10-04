using StaticArrays

"""
    FunctionCall{N}

Type representing a function call with `N` parameters. Contains the function to call, argument symbols, the return symbol and the device to execute on.
"""
mutable struct FunctionCall{VectorType<:AbstractVector,N}
    func::Function
    # TODO: this should be a tuple
    value_arguments::SVector{N,Any}    # value arguments for the function call, will be prepended to the other arguments
    arguments::VectorType              # symbols of the inputs to the function call
    return_symbol::Symbol
    return_type::Type
    device::AbstractDevice
end

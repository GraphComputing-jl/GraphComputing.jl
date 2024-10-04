"""
    AbstractDevice

Abstract base type for every device, like GPUs, CPUs or any other compute devices.
Every implementation needs to implement various functions and needs a member `cacheStrategy`.
"""
abstract type AbstractDevice end

abstract type AbstractCPU <: AbstractDevice end

abstract type AbstractGPU <: AbstractDevice end

"""
    Machine

A representation of a machine to execute on. Contains information about its architecture (CPUs, GPUs, maybe more). This representation can be used to make a more accurate cost prediction of a [`DAG`](@ref) state.

See also: [`Scheduler`](@ref)
"""
struct Machine
    devices::Vector{AbstractDevice}

    transferRates::Matrix{Float64}
end

"""
    CacheStrategy

Abstract base type for caching strategies.

See also: [`strategies`](@ref)
"""
abstract type CacheStrategy end

"""
    LocalVariables <: CacheStrategy

A caching strategy relying solely on local variables for every input and output.

Implements the [`CacheStrategy`](@ref) interface.
"""
struct LocalVariables <: CacheStrategy end

"""
    Dictionary <: CacheStrategy

A caching strategy relying on a dictionary of Symbols to store every input and output.

Implements the [`CacheStrategy`](@ref) interface.
"""
struct Dictionary <: CacheStrategy end

"""
    DEVICE_TYPES::Vector{Type}

Global vector of available and implemented device types. Each implementation of a [`AbstractDevice`](@ref) should add its concrete type to this vector.

See also: [`device_types`](@ref), [`get_devices`](@ref)
"""
DEVICE_TYPES = Vector{Type}()

"""
    CACHE_STRATEGIES::Dict{Type{AbstractDevice}, Symbol}

Global dictionary of available caching strategies per device. Each implementation of [`AbstractDevice`](@ref) should add its available strategies to the dictionary.

See also: [`strategies`](@ref)
"""
CACHE_STRATEGIES = Dict{Type,Vector{CacheStrategy}}()

"""
    default_strategy(deviceType::Type{T}) where {T <: AbstractDevice}

Interface function that must be implemented for every subtype of [`AbstractDevice`](@ref). Returns the default [`CacheStrategy`](@ref) to use on the given device type.
See also: [`cache_strategy`](@ref), [`set_cache_strategy`](@ref)
"""
function default_strategy end

"""
    get_devices(t::Type{T}; verbose::Bool) where {T <: AbstractDevice}

Interface function that must be implemented for every subtype of [`AbstractDevice`](@ref). Returns a `Vector{Type}` of the devices for the given [`AbstractDevice`](@ref) Type available on the current machine.
"""
function get_devices end

"""
    measure_device!(device::AbstractDevice; verbose::Bool)

Interface function that must be implemented for every subtype of [`AbstractDevice`](@ref). Measures the compute speed of the given device and writes into it.
"""
function measure_device! end

"""
    gen_cache_init_code(device::AbstractDevice)

Interface function that must be implemented for every subtype of [`AbstractDevice`](@ref) and at least one [`CacheStrategy`](@ref). Returns an `Expr` initializing this device's variable cache.
    
The strategy is a symbol
"""
function gen_cache_init_code end

"""
    _gen_access_expr(device::AbstractDevice, cache_strategy::CacheStrategy, symbol::Symbol)

Interface function that must be implemented for every subtype of [`AbstractDevice`](@ref) and at least one [`CacheStrategy`](@ref).
Return an `Expr` or `QuoteNode` accessing the variable identified by [`symbol`].
"""
function _gen_access_expr end

"""
    _gen_local_init(fc::FunctionCall, device::AbstractDevice, cache_strategy::CacheStrategy)

Interface function that must be implemented for every subtype of [`AbstractDevice`](@ref) and at least one [`CacheStrategy`](@ref).
Return an `Expr` or `QuoteNode` that initializes the access expression returned by [`_gen_access_expr`](@ref) in the local scope.
This expression may be empty. For local variables it should be `local <variable_name>::<Type>`.
"""
function _gen_local_init end

"""
    kernel(gpu_type::Type{<:AbstractGPU}, graph::DAG, instance)

For a GPU type, a [`DAG`](@ref), and a problem instance, return an `Expr` containing a function of signature `compute_<id>(input::<GPU>Vector, output::<GPU>Vector, n::Int64)`, which will return the result of the DAG computation of the input on the given output vector, intended for computation on GPUs. Currently, `CUDAGPU` and `ROCmGPU` are available if their respective package extensions are loaded.

The generated kernel function accepts its thread ID in only the x-dimension, and only as thread ID, not as block ID. The input and output should therefore be 1-dimensional vectors. For detailed information on GPU programming and the Julia packages, please refer to their respective documentations.

A simple example call for a CUDA kernel might look like the following:
```Julia
@cuda threads = (32,) always_inline = true cuda_kernel!(cu_inputs, outputs, length(cu_inputs))
```

!!! note
    Unlike the standard [`get_compute_function`](@ref) to generate a callable function which returns a `RuntimeGeneratedFunction`, this returns an `Expr` that needs to be `eval`'d. This is a current limitation of `RuntimeGeneratedFunctions.jl` which currently cannot wrap GPU kernels. This might change in the future.

### Size limitation

The generated kernel does not use any internal parallelization, i.e., the DAG is compiled into a serialized function, processing each input in a single thread of the GPU. This means it can be heavily parallelized and use the GPU at 100% for sufficiently large input vectors (and assuming the function does not become IO limited etc.). However, it also means that there is a limit to how large the compiled function can be. If it gets too large, the compilation might fail, take too long to complete, the kernel might fail during execution if too much stack memory is required, or other similar problems. If this happens, your problem is likely too large to be compiled to a GPU kernel like this.

### Compute Requirements

A GPU function has more restrictions on what can be computed than general functions running on the CPU. In Julia, there are mainly two important restrictions to consider: 
    
1. Used data types must be stack allocatable, i.e., `isbits(x)` must be `true` for arguments and local variables used in `ComputeTasks`.
2. Function calls must not be dynamic. This means that type stability is required and the compiler must know in advance which method of a generic function to call. What this specifically entails may change with time and also differs between the different target GPU libraries. From experience, using the `always_inline = true` argument for `@cuda` calls can help with this.

!!! warning
    This feature is currently experimental. There are still some unresolved issues with the generated kernels.
"""
function kernel end

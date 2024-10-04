
"""
    AbstractScheduler

Abstract base type for scheduler implementations. The scheduler is used to assign each node to a device and create a topological ordering of tasks.
"""
abstract type AbstractScheduler end

"""
    schedule_dag(::Scheduler, ::DAG, ::Machine)

Interface functions that must be implemented for implementations of [`Scheduler`](@ref).

The function assigns each [`ComputeTaskNode`](@ref) of the [`DAG`](@ref) to one of the devices in the given [`Machine`](@ref) and returns a `Vector{Node}` representing a topological ordering.

[`DataTaskNode`](@ref)s are not scheduled to devices since they do not compute. Instead, a data node transfers data from the [`AbstractDevice`](@ref) of their child to all [`AbstractDevice`](@ref)s of its parents.

The produced schedule can be converted to [`FunctionCall`](@ref)s using [`lower`](@ref).
"""
function schedule_dag end

"""
    ComputableDAGs

A module containing tools to represent computations as DAGs.
"""
module ComputableDAGs

using RuntimeGeneratedFunctions
RuntimeGeneratedFunctions.init(@__MODULE__)

# graph types
export DAG, Node, Edge
export ComputeTaskNode, DataTaskNode
export AbstractTask, AbstractComputeTask, AbstractDataTask
export DataTask
export PossibleOperations
export GraphProperties

# graph functions
export make_node, make_edge
export insert_node!, insert_edge!
export is_entry_node, is_exit_node
export parents, children, partners, siblings
export compute, data, compute_effort, task
export get_properties, get_exit_node
export operation_stack_length
export is_valid, is_scheduled

# graph operation related
export Operation, AppliedOperation
export NodeReduction, NodeSplit
export push_operation!, pop_operation!, can_pop
export reset_graph!
export get_operations

# code generation related
export execute
export get_compute_function
export gen_tape, execute_tape
export unpack_identity

# estimator
export cost_type, graph_cost, operation_effect
export GlobalMetricEstimator, CDCost

# optimization
export AbstractOptimizer, GreedyOptimizer, RandomWalkOptimizer
export ReductionOptimizer, SplitOptimizer
export optimize_step!, optimize!
export fixpoint_reached, optimize_to_fixpoint!

# models
export AbstractModel, AbstractProblemInstance
export problem_instance, input_type, graph, input_expr

# machine info
export Machine
export NumaNode
export get_machine_info, cpu_st
export CacheStrategy, default_strategy
export LocalVariables, Dictionary

# GPU Extensions
export kernel, CUDAGPU, ROCmGPU, oneAPIGPU

include("devices/interface.jl")
include("task/type.jl")
include("node/type.jl")
include("diff/type.jl")
include("properties/type.jl")
include("operation/type.jl")
include("graph/type.jl")
include("scheduler/type.jl")

include("trie.jl")
include("utils.jl")

include("diff/print.jl")
include("diff/properties.jl")

include("graph/compare.jl")
include("graph/interface.jl")
include("graph/mute.jl")
include("graph/print.jl")
include("graph/properties.jl")
include("graph/validate.jl")

include("node/compare.jl")
include("node/create.jl")
include("node/print.jl")
include("node/properties.jl")
include("node/validate.jl")

include("operation/utility.jl")
include("operation/iterate.jl")
include("operation/apply.jl")
include("operation/clean.jl")
include("operation/find.jl")
include("operation/get.jl")
include("operation/print.jl")
include("operation/validate.jl")

include("properties/create.jl")
include("properties/utility.jl")

include("task/create.jl")
include("task/compare.jl")
include("task/compute.jl")
include("task/properties.jl")

include("estimator/interface.jl")
include("estimator/global_metric.jl")

include("optimization/interface.jl")
include("optimization/greedy.jl")
include("optimization/random_walk.jl")
include("optimization/reduce.jl")
include("optimization/split.jl")

include("models/interface.jl")

include("devices/measure.jl")
include("devices/detect.jl")
include("devices/impl.jl")

include("devices/numa/impl.jl")
include("devices/ext.jl")

include("scheduler/interface.jl")
include("scheduler/greedy.jl")

include("code_gen/type.jl")
include("code_gen/utils.jl")
include("code_gen/tape_machine.jl")
include("code_gen/function.jl")

end # module ComputableDAGs

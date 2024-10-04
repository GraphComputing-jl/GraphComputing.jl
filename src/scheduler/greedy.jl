
"""
    GreedyScheduler

A greedy implementation of a scheduler, creating a topological ordering of nodes and naively balancing them onto the different devices.
"""
struct GreedyScheduler <: AbstractScheduler end

function schedule_dag(::GreedyScheduler, graph::DAG, machine::Machine)
    node_queue = PriorityQueue{Node,Int}()

    # use a priority equal to the number of unseen children -> 0 are nodes that can be added
    for node in get_entry_nodes(graph)
        enqueue!(node_queue, node => 0)
    end

    schedule = Vector{Node}()
    sizehint!(schedule, length(graph.nodes))

    # keep an accumulated cost of things scheduled to this device so far
    device_acc_cost = PriorityQueue{AbstractDevice,Float64}()
    for device in machine.devices
        enqueue!(device_acc_cost, device => 0)
    end

    local node
    while !isempty(node_queue)
        @assert peek(node_queue)[2] == 0
        node = dequeue!(node_queue)

        # assign the device with lowest accumulated cost to the node (if it's a compute node)
        if (isa(node, ComputeTaskNode))
            lowest_device = peek(device_acc_cost)[1]
            node.device = lowest_device
            device_acc_cost[lowest_device] = compute_effort(task(node))
        end

        push!(schedule, node)

        for parent in parents(node)
            # reduce the priority of all parents by one
            if (!haskey(node_queue, parent))
                enqueue!(node_queue, parent => length(children(parent)) - 1)
            else
                node_queue[parent] = node_queue[parent] - 1
            end
        end
    end

    return schedule
end

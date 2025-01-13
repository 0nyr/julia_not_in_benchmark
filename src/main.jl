using Random
using BenchmarkTools
using Plots
using CairoMakie
using Printf

# Parameters
NB_VERTICES = 1000  # Number of vertices
NB_ROUTES = 1000  # Number of routes to generate
MAX_ROUTE_SIZE = 1000  # Maximum route size
ITERATIONS = 100  # Number of iterations for each test

# Generate random data
function generate_data(nb_routes, max_route_size, nb_vertices)
    routes = [rand(1:nb_vertices, rand(1:max_route_size)) for _ in 1:nb_routes]
    nodes = rand(1:nb_vertices, nb_routes)  # Random nodes to test against
    return routes, nodes
end

# Define methods to test
function method_1(node, route)
    !(node in route)
end

function method_2(node, route)
    !any(isequal(node), route)
end

function method_3(node, route)
    all(x -> x != node, route)
end

function method_4(node, route)
    for r in route
        if r == node
            return false
        end
    end
    return true
end

function method_5(node, route)
    @simd for r in route
        if r == node
            return false
        end
    end
    return true
end

function test_is_in(method)
    node = 1
    route = [i for i in 1:100]
    res = method(node, route)
    @assert res == false
end

function test_is_not_in(method)
    node = 101
    route = [i for i in 1:100]
    res = method(node, route)
    @assert res == true
end

for method in [method_1, method_2, method_3, method_4, method_5]
    test_is_in(method)
    test_is_not_in(method)
end

function testing(routes, nodes, method)
    for i in 1:length(nodes)
        node = nodes[i]
        route = routes[i]
        method(node, route)
    end
end

METHODS::Vector{Tuple{String, Function}} = [
    ("!in", method_1),
    ("any", method_2),
    ("all", method_3),
    ("for", method_4),
    ("sfor", method_5),
]

# Benchmarking function
function benchmark_methods(
    nb_routes, 
    max_route_size, 
    nb_vertices, 
    iterations
)
    results::Matrix{Float64} = zeros(length(METHODS), iterations)
    routes, nodes = generate_data(nb_routes, max_route_size, nb_vertices)

    for iter in 1:iterations
        for method_id in 1:length(METHODS)
            method = METHODS[method_id][2]
            t = @belapsed testing($routes, $nodes, $method)
            results[method_id, iter] = t
        end
    end
    return results
end

# Run the benchmarks
results = benchmark_methods(
    NB_ROUTES, 
    MAX_ROUTE_SIZE, 
    NB_VERTICES, 
    ITERATIONS
)

# pretty print results
for method_id in 1:length(METHODS)
    method_name = METHODS[method_id][1]
    method_results = results[method_id, :]
    print("Method: $method_name ")
    print("Results: [$(join([@sprintf("%.2e", r) for r in method_results], ", "))] ")
    print("Mean: $(mean(method_results)) ")
    println("Std: $(std(method_results))")
end

# Plot results
fig = Figure()

nb_methods = length(METHODS)
categories = Vector{Int}(undef, ITERATIONS*nb_methods)
all_values = Vector{Float64}(undef, ITERATIONS*nb_methods)
for i in 1:nb_methods
    print("Method $i: $(METHODS[i][1]) ")
    categories[(i-1)*ITERATIONS+1:i*ITERATIONS] .= i
    all_values[(i-1)*ITERATIONS+1:i*ITERATIONS] .= results[i, :]
end

ax_vert = Axis(fig[1,1];
    xlabel = "categories",
    ylabel = "values",
    xticks = (1:nb_methods, [METHODS[i][1] for i in 1:nb_methods]),
)
ax_vert_boxplot = Axis(
    fig[1,2]; 
    xlabel = "categories", 
    ylabel = "values",
    xticks = (1:nb_methods, [METHODS[i][1] for i in 1:nb_methods]),
)

# Note: same order of category/value, despite different axes
CairoMakie.violin!(ax_vert, categories, all_values) # `orientation=:vertical` is default

# display a boxplot as well
CairoMakie.boxplot!(ax_vert_boxplot, categories, all_values)


display(fig)

save("plots/violin_plot_compare_in.png", fig)

# Save the plot


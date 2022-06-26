"""
    AsTable(cols)

A type having a special meaning in `source => transformation => destination`
selection operations supported by [`combine`](@ref), [`select`](@ref), [`select!`](@ref),
[`transform`](@ref), [`transform!`](@ref), [`subset`](@ref), and [`subset!`](@ref).

If `AsTable(cols)` is used in `source` position it signals that the columns selected
by the wrapped selector `cols` should be passed as a `NamedTuple` to the function.

If `AsTable` is used in `destination` position it means that the result of
the `transformation` operation is a vector of containers
(or a single container if `ByRow(transformation)` is used)
that should be expanded  into multiple columns using `keys` to get column names.

# Examples
```jldoctest
julia> df1 = DataFrame(a=1:3, b=11:13)
3×2 DataFrame
 Row │ a      b
     │ Int64  Int64
─────┼──────────────
   1 │     1     11
   2 │     2     12
   3 │     3     13

julia> df2 = select(df1, AsTable([:a, :b]) => ByRow(identity))
3×1 DataFrame
 Row │ a_b_identity
     │ NamedTuple…
─────┼─────────────────
   1 │ (a = 1, b = 11)
   2 │ (a = 2, b = 12)
   3 │ (a = 3, b = 13)

julia> select(df2, :a_b_identity => AsTable)
3×2 DataFrame
 Row │ a      b
     │ Int64  Int64
─────┼──────────────
   1 │     1     11
   2 │     2     12
   3 │     3     13

julia> select(df1, AsTable([:a, :b]) => ByRow(nt -> map(x -> x^2, nt)) => AsTable)
3×2 DataFrame
 Row │ a      b
     │ Int64  Int64
─────┼──────────────
   1 │     1    121
   2 │     4    144
   3 │     9    169
```
"""
struct AsTable
    cols

    # the rules used here are simplified as not all column selectors
    # that pass through them are valid, but this is safe enough in practice
    function AsTable(cols)
        if cols isa Union{AbstractString, Symbol, Signed, Unsigned,
                          AbstractVector{<:Integer},
                          AbstractVector{Symbol},
                          AbstractVector{<:AbstractString},
                          Colon, Not, Between, All, Cols, Regex} ||
            (cols isa AbstractVector &&
             all(col -> col isa Union{Integer, Symbol, AbstractString}, cols))
            return new(cols)
        else
            throw(ArgumentError("Unrecognized column selector $cols"))
        end
    end
end

Base.broadcastable(x::AsTable) = Ref(x)

function make_unique!(names::Vector{Symbol}, src::AbstractVector{Symbol};
                      makeunique::Bool=false)
    if length(names) != length(src)
        throw(DimensionMismatch("Length of src doesn't match length of names."))
    end
    seen = Set{Symbol}()
    dups = Int[]
    for i in 1:length(names)
        name = src[i]
        if in(name, seen)
            push!(dups, i)
        else
            names[i] = src[i]
            push!(seen, name)
        end
    end

    if length(dups) > 0
        if !makeunique
            dupstr = join(string.(':', unique(src[dups])), ", ", " and ")
            msg = "Duplicate variable names: $dupstr. Pass makeunique=true " *
                  "to make them unique using a suffix automatically."
            throw(ArgumentError(msg))
        end
    end

    for i in dups
        nm = src[i]
        k = 1
        while true
            newnm = Symbol("$(nm)_$k")
            if !in(newnm, seen)
                names[i] = newnm
                push!(seen, newnm)
                break
            end
            k += 1
        end
    end

    return names
end

function make_unique(names::AbstractVector{Symbol}; makeunique::Bool=false)
    make_unique!(similar(names), names, makeunique=makeunique)
end

"""
    gennames(n::Integer)

Generate standardized names for columns of a DataFrame.
The first name will be `:x1`, the second `:x2`, etc.
"""
function gennames(n::Integer)
    res = Vector{Symbol}(undef, n)
    for i in 1:n
        res[i] = Symbol(@sprintf "x%d" i)
    end
    return res
end

function funname(f)
    if applicable(nameof, f)
        n = nameof(f)
        return String(n)[1] == '#' ? :function : n
    else
        # handle the case of functors that do not support nameof
        return :function
    end
end

funname(c::ComposedFunction) = Symbol(funname(c.outer), :_, funname(c.inner))

# Compute chunks of indices, each with at least `basesize` entries
# This method ensures balanced sizes by avoiding a small last chunk
function split_indices(len::Integer, basesize::Integer)
    len′ = Int64(len) # Avoid overflow on 32-bit machines
    @assert len′ > 0
    @assert basesize > 0
    np = Int64(max(1, len ÷ basesize))
    return split_to_chunks(len′, np)
end

function split_to_chunks(len::Integer, np::Integer)
    len′ = Int64(len) # Avoid overflow on 32-bit machines
    np′ = Int64(np)
    @assert len′ > 0
    @assert 0 < np′ <= len′
    return (Int(1 + ((i - 1) * len′) ÷ np):Int((i * len′) ÷ np) for i in 1:np)
end

if VERSION >= v"1.4"
    function _spawn_for_chunks_helper(iter, lbody, basesize)
        lidx = iter.args[1]
        range = iter.args[2]
        quote
            let x = $(esc(range)), basesize = $(esc(basesize))
                @assert firstindex(x) == 1

                nt = Threads.nthreads()
                len = length(x)
                if nt > 1 && len > basesize
                    tasks = [Threads.@spawn begin
                                 for i in p
                                     local $(esc(lidx)) = @inbounds x[i]
                                     $(esc(lbody))
                                 end
                             end
                             for p in split_indices(len, basesize)]
                    foreach(wait, tasks)
                else
                    for i in eachindex(x)
                        local $(esc(lidx)) = @inbounds x[i]
                        $(esc(lbody))
                    end
                end
            end
            nothing
        end
    end
else
    function _spawn_for_chunks_helper(iter, lbody, basesize)
        lidx = iter.args[1]
        range = iter.args[2]
        quote
            let x = $(esc(range))
                for i in eachindex(x)
                    local $(esc(lidx)) = @inbounds x[i]
                    $(esc(lbody))
                end
            end
            nothing
        end
    end
end

"""
    @spawn_for_chunks basesize for i in range ... end

Parallelize a `for` loop by spawning separate tasks
iterating each over a chunk of at least `basesize` elements
in `range`.

A number of tasks higher than `Threads.nthreads()` may be spawned,
since that can allow for a more efficient load balancing in case
some threads are busy (nested parallelism).
"""
macro spawn_for_chunks(basesize, ex)
    if !(isa(ex, Expr) && ex.head === :for)
        throw(ArgumentError("@spawn_for_chunks requires a `for` loop expression"))
    end
    if !(ex.args[1] isa Expr && ex.args[1].head === :(=))
        throw(ArgumentError("nested outer loops are not currently supported by @spawn_for_chunks"))
    end
    return _spawn_for_chunks_helper(ex.args[1], ex.args[2], basesize)
end

"""
    @spawn_or_run_task threads expr

Equivalent to `Threads.@spawn` if `threads === true`,
otherwise run `expr` and return a `Task` that returns its value.
"""
macro spawn_or_run_task end

"""
    @spawn_or_run threads expr

Equivalent to `Threads.@spawn` if `threads === true`,
otherwise run `expr`.
"""
macro spawn_or_run end

if VERSION >= v"1.4"
    macro spawn_or_run_task(threads, expr)
        letargs = Base._lift_one_interp!(expr)

        thunk = esc(:(()->($expr)))
        var = esc(Base.sync_varname)
        quote
            let $(letargs...)
                if $(esc(threads))
                    local task = Task($thunk)
                    task.sticky = false
                else
                    # Run expr immediately
                    res = $thunk()
                    # Return a Task that returns the value of expr
                    local task = Task(() -> res)
                    task.sticky = true
                end
                if $(Expr(:islocal, var))
                    @static if VERSION >= v"1.5.0"
                        put!($var, task)
                    else
                        push!($var, task)
                    end
                end
                schedule(task)
                task
            end
        end
    end

    macro spawn_or_run(threads, expr)
        letargs = Base._lift_one_interp!(expr)

        thunk = esc(:(()->($expr)))
        var = esc(Base.sync_varname)
        quote
            let $(letargs...)
                if $(esc(threads))
                    local task = Task($thunk)
                    task.sticky = false
                    if $(Expr(:islocal, var))
                        @static if VERSION >= v"1.5.0"
                            put!($var, task)
                        else
                            push!($var, task)
                        end
                    end
                    schedule(task)
                else
                    $thunk()
                end
                nothing
            end
        end
    end
else
    # Based on the definition of @async in Base
    macro spawn_or_run_task(threads, expr)
        thunk = esc(:(()->($expr)))
        var = esc(Base.sync_varname)
        quote
            # Run expr immediately
            res = $thunk()
            # Return a Task that returns the value of expr
            local task = Task(() -> res)
            if $(Expr(:isdefined, var))
                push!($var, task)
            end
            schedule(task)
        end
    end

    macro spawn_or_run(threads, expr)
        esc(:($expr; nothing))
    end
end

function _nt_like_hash(v, h::UInt)
    length(v) == 0 && return hash(NamedTuple(), h)

    h = hash((), h)
    for i in length(v):-1:1
        h = hash(v[i], h)
    end

    return xor(objectid(Tuple(propertynames(v))), h)
end

_findall(B) = findall(B)

function _findall(B::AbstractVector{Bool})
    @assert firstindex(B) == 1
    nnzB = count(B)

    # fast path returning range
    nnzB == 0 && return 1:0
    len = length(B)
    nnzB == len && return 1:len
    start::Int = findfirst(B)
    nnzB == 1 && return start:start
    start + nnzB - 1 == len && return start:len
    stop::Int = findnext(!, B, start + 1) - 1
    start + nnzB == stop + 1 && return start:stop

    # slow path returning Vector{Int}
    I = Vector{Int}(undef, nnzB)
    @inbounds for i in 1:stop - start + 1
        I[i] = start + i - 1
    end
    cnt = stop - start + 2
    @inbounds for i in stop+1:len
        if B[i]
            I[cnt] = i
            cnt += 1
        end
    end
    @assert cnt == nnzB + 1
    return I
end

@inline _blsr(x) = x & (x-1)

# findall returning a range when possible (all true indices are contiguous), and optimized for B::BitVector
# the main idea is taken from Base.findall(B::BitArray)
function _findall(B::BitVector)::Union{UnitRange{Int}, Vector{Int}}
    nnzB = count(B)
    nnzB == 0 && return 1:0
    nnzB == length(B) && return 1:length(B)
    local I
    Bc = B.chunks
    Bi = 1 # block index
    i1 = 1 # index of current block beginng in B
    i = 1  # index of the _next_ one in I
    c = Bc[1] # current block

    start = -1 # the begining of ones block
    stop = -1  # the end of ones block

    @inbounds while true # I not materialized
        if i > nnzB # all ones in B found
            Ir = start:start + i - 2
            @assert length(Ir) == nnzB
            return Ir
        end

        if c == 0
            if start != -1 && stop == -1
                stop = i1 - 1
            end
            while c == 0 # no need to return here as we returned above
                i1 += 64
                Bi += 1
                c = Bc[Bi]
            end
        end
        if c == ~UInt64(0)
            if stop != -1
                I = Vector{Int}(undef, nnzB)
                for j in 1:i-1
                    I[j] = start + j - 1
                end
                break
            end
            if start == -1
                start = i1
            end
            while c == ~UInt64(0)
                if Bi == length(Bc)
                    Ir = start:length(B)
                    @assert length(Ir) == nnzB
                    return Ir
                end

                i += 64
                i1 += 64
                Bi += 1
                c = Bc[Bi]
            end
        end
        if c != 0 # mixed ones and zeros in block
            tz = trailing_zeros(c)
            lz = leading_zeros(c)
            co = c >> tz == (one(UInt64) << (64 - lz - tz)) - 1 # block of countinous ones in c
            if stop != -1  # already found block of ones and zeros, just not materialized
                I = Vector{Int}(undef, nnzB)
                for j in 1:i-1
                    I[j] = start + j - 1
                end
                break
            elseif !co # not countinous ones
                I = Vector{Int}(undef, nnzB)
                if start != -1
                    for j in 1:i-1
                        I[j] = start + j - 1
                    end
                end
                break
            else # countinous block of ones
                if start != -1
                    if tz > 0 # like __1111__ or 111111__
                        I = Vector{Int}(undef, nnzB)
                        for j in 1:i-1
                            I[j] = start + j - 1
                        end
                        break
                    else # lz > 0, like __111111
                        stop = i1 + (64 - lz) - 1
                        i += 64 - lz

                        # return if last block
                        if Bi == length(Bc)
                            Ir = start:stop
                            @assert length(Ir) == nnzB
                            return Ir
                        end

                        i1 += 64
                        Bi += 1
                        c = Bc[Bi]
                    end
                else # start == -1
                    start = i1 + tz

                    if lz > 0 # like __111111 or like __1111__
                        stop = i1 + (64 - lz) - 1
                        i += stop - start + 1
                    else # like 111111__
                        i += 64 - tz
                    end

                    # return if last block
                    if Bi == length(Bc)
                        Ir = start:start + i - 2
                        @assert length(Ir) == nnzB
                        return Ir
                    end

                    i1 += 64
                    Bi += 1
                    c = Bc[Bi]
                end
            end
        end
    end
    @inbounds while true # I materialized, process like in Base.findall
        if i > nnzB # all ones in B found
            @assert nnzB == i - 1
            return I
        end

        while c == 0 # no need to return here as we returned above
            i1 += 64
            Bi += 1
            c = Bc[Bi]
        end

        while c == ~UInt64(0)
            for j in 0:64-1
                I[i + j] = i1 + j
            end
            i += 64
            if Bi == length(Bc)
                @assert nnzB == i - 1
                return I
            end
            i1 += 64
            Bi += 1
            c = Bc[Bi]
        end

        while c != 0
            tz = trailing_zeros(c)
            c = _blsr(c) # zeros last nonzero bit
            I[i] = i1 + tz
            i += 1
        end
    end
    @assert false "should not be reached"
end

function _drop_metadata!(df::DataFrame)
    setfield!(df, :metadata, nothing)
    return nothing
end

function _drop_colmetadata!(df::DataFrame)
    setfield!(df, :colmetadata, nothing)
    return nothing
end

function _drop_colmetadata!(df::DataFrame, col::ColumnIndex)
    colmetadata = getfield(df, :colmetadata)
    if colmetadata !== nothing
        delete!(colmetadata, index(df)[col])
    end
    return nothing
end

function _copy_metadata!(dst::DataFrame, src)
    if hasmetadata(src) === true
        copy!(metadata(dst), metadata(src))
    else
        _drop_metadata!(df)
    end
    return nothing
end

function _copy_colmetadata!(dst::DataFrame, dstcol::ColumnIndex,
                            src, srccol::ColumnIndex)
    if hascolmetadata(src, srccol) === true
        copy!(metadata(dst, dstcol), metadata(src, srccol))
    else
        _drop_colmetadata!(dst, col)
    end
    return nothing
end

# this is a function used to copy metadata
# to a freshly allocated dst without metadata that is `similar` to src
function _unsafe_copy_all_metadata_similar!(dst::DataFrame, src::AbstractDataFrame)
    _copy_metadata(dst, src)
    # parent(src) is guaranteed to be DataFrame
    src_colmetadata = getfield(parent(src), :colmetadata)
    if isnothing(src_colmetadata)
        _drop_colmetadata!(dst)
    else
        dst_colmetadata = Dict{Int, Dict{String, Any}}()
        for (k, v) in pairs(src_colmetadata)
            dst_colmetadata[k] = copy(v)
        end
        setfield!(dst, :colmetadata, dst_colmetadata)
    end
    return nothing
end

# this is a function used to copy metadata
# to a freshly allocated dst without metadata where column names
# in dst is a subset of column names in src
function _unsafe_copy_all_metadata!(dst::DataFrame, src::AbstractDataFrame)
    _copy_metadata(dst, src)
    # parent(src) is guaranteed to be DataFrame
    src_colmetadata = getfield(parent(src), :colmetadata)
    if isnothing(src_colmetadata)
        _drop_colmetadata!(dst)
    else
        for col in _names(dst)
            _copy_colmetadata!(dst, col, src, col)
        end
    end
    return nothing
end
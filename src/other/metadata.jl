# TODO: remove when DataAPI.jl version is bumped
metadata(::T, ::AbstractString; style::Bool=false) where {T} =
    throw(ArgumentError("Objects of type $T do not support getting metadata"))
metadatakeys(::Any) = ()
metadata!(::T, ::AbstractString, ::Any; style) where {T} =
    throw(ArgumentError("Objects of type $T do not support setting metadata"))
deletemetadata!(::T, ::AbstractString) where {T} =
    throw(ArgumentError("Objects of type $T do not support metadata deletion"))
emptymetadata!(::T) where {T} =
    throw(ArgumentError("Objects of type $T do not support metadata deletion"))
colmetadata(::T, ::Int, ::AbstractString; style::Bool=false) where {T} =
    throw(ArgumentError("Objects of type $T do not support getting column metadata"))
colmetadata(::T, ::Symbol, ::AbstractString; style::Bool=false) where {T} =
    throw(ArgumentError("Objects of type $T do not support getting column metadata"))
colmetadatakeys(::Any, ::Int) = ()
colmetadatakeys(::Any, ::Symbol) = ()
colmetadatakeys(::Any) = ()
colmetadata!(::T, ::Int, ::AbstractString, ::Any; style) where {T} =
    throw(ArgumentError("Objects of type $T do not support setting metadata"))
colmetadata!(::T, ::Symbol, ::AbstractString, ::Any; style) where {T} =
    throw(ArgumentError("Objects of type $T do not support setting metadata"))
deletecolmetadata!(::T, ::Symbol, ::AbstractString) where {T} =
    throw(ArgumentError("Objects of type $T do not support metadata deletion"))
deletecolmetadata!(::T, ::Int, ::AbstractString) where {T} =
    throw(ArgumentError("Objects of type $T do not support metadata deletion"))
emptycolmetadata!(::T, ::Symbol) where {T} =
    throw(ArgumentError("Objects of type $T do not support metadata deletion"))
emptycolmetadata!(::T, ::Int) where {T} =
    throw(ArgumentError("Objects of type $T do not support metadata deletion"))
emptycolmetadata!(::T) where {T} =
    throw(ArgumentError("Objects of type $T do not support metadata deletion"))

### Metadata API from DataAPI.jl

"""
    metadata(df::AbstractDataFrame, key::AbstractString; style::Bool=false)
    metadata(dfr::DataFrameRow, key::AbstractString; style::Bool=false)
    metadata(dfc::DataFrameColumns, key::AbstractString; style::Bool=false)
    metadata(dfr::DataFrameRows, key::AbstractString; style::Bool=false)
    metadata(gdf::GroupedDataFrame, key::AbstractString; style::Bool=false)

Return table level metadata value associated with `df` for key `key`.
If `style=true` return a tuple of metadata value and metadata style.

`SubDataFrame` and `DataFrameRow` expose only `:note` style metadata of their
parent.

See also: [`metadatakeys`](@ref), [`metadata!`](@ref),
[`deletemetadata!`](@ref), [`emptymetadata!`](@ref),
[`colmetadata`](@ref), [`colmetadatakeys`](@ref), [`colmetadata!`](@ref),
[`deletecolmetadata!`](@ref), [`emptycolmetadata!`](@ref).

# Examples

```jldoctest
julia> df = DataFrame(a=1, b=2);

julia> metadatakeys(df)
()

julia> metadata!(df, "name", "example", style=:note);

julia> metadatakeys(df)
KeySet for a Dict{String, Tuple{Any, Any}} with 1 entry. Keys:
  "name"

julia> metadata(df, "name")
"example"
```
"""
function metadata(df::DataFrame, key::AbstractString; style::Bool=false)
    meta = getfield(df, :metadata)
    meta === nothing && throw(KeyError("Metadata for key $key not found"))
    return style ? meta[key] : meta[key][1]
end

"""
    metadatakeys(df::AbstractDataFrame)
    metadatakeys(dfr::DataFrameRow)
    metadatakeys(dfc::DataFrameColumns)
    metadatakeys(dfr::DataFrameRows)
    metadatakeys(gdf::GroupedDataFrame)

Return an iterator of table level metadata keys for which `metadata(df, key)`
returns a metadata value.

`SubDataFrame` and `DataFrameRow` expose only `:note` style metadata keys of
their parent.

See also: [`metadata`](@ref), [`metadata!`](@ref),
[`deletemetadata!`](@ref), [`emptymetadata!`](@ref),
[`colmetadata`](@ref), [`colmetadatakeys`](@ref), [`colmetadata!`](@ref),
[`deletecolmetadata!`](@ref), [`emptycolmetadata!`](@ref).

# Examples

```jldoctest
julia> df = DataFrame(a=1, b=2);

julia> metadatakeys(df)
()

julia> metadata!(df, "name", "example", style=:note);

julia> metadatakeys(df)
KeySet for a Dict{String, Tuple{Any, Any}} with 1 entry. Keys:
  "name"

julia> metadata(df, "name")
"example"
```
"""
function metadatakeys(df::DataFrame)
    meta = getfield(df, :metadata)
    meta === nothing && return ()
    metakeys = keys(meta)
    @assert !isempty(metakeys) # by design in such cases meta === nothing should be met
    return metakeys
end

"""
    metadata!(df::AbstractDataFrame, key::AbstractString, value; style)
    metadata!(dfr::DataFrameRow, key::AbstractString, value; style)
    metadata!(dfc::DataFrameColumns, key::AbstractString, value; style)
    metadata!(dfr::DataFrameRows, key::AbstractString, value; style)
    metadata!(gdf::GroupedDataFrame, key::AbstractString, value; style)

Set table level metadata for object `df` for key `key` to have value `value`
and style `style` and return `df`.

For `SubDataFrame` and `DataFrameRow` only `:note` style for metadata is allowed.
Trying to add key-value pair such that in the parent data frame already
mapping for key exists with `:none` style throws an error.

See also: [`metadata`](@ref), [`metadatakeys`](@ref),
[`deletemetadata!`](@ref), [`emptymetadata!`](@ref),
[`colmetadata`](@ref), [`colmetadatakeys`](@ref), [`colmetadata!`](@ref),
[`deletecolmetadata!`](@ref), [`emptycolmetadata!`](@ref).

# Examples

```jldoctest
julia> df = DataFrame(a=1, b=2);

julia> metadatakeys(df)
()

julia> metadata!(df, "name", "example", style=:note);

julia> metadatakeys(df)
KeySet for a Dict{String, Tuple{Any, Any}} with 1 entry. Keys:
  "name"

julia> metadata(df, "name")
"example"
```
"""
function metadata!(df::DataFrame, key::AbstractString, value::Any; style)
    premeta = getfield(df, :metadata)
    if premeta === nothing
        meta = Dict{String, Tuple{Any, Any}}()
        setfield!(df, :metadata, meta)
    else
        meta = premeta
    end
    meta[key] = (value, style)
    return df
end

"""
    deletemetadata!(df::AbstractDataFrame, key::AbstractString)
    deletemetadata!(dfr::DataFrameRow, key::AbstractString)
    deletemetadata!(dfc::DataFrameColumns, key::AbstractString)
    deletemetadata!(dfr::DataFrameRows, key::AbstractString)
    deletemetadata!(gdf::GroupedDataFrame, key::AbstractString)

Delete table level metadata from object `df` for key `key`.

For `SubDataFrame` and `DataFrameRow` only `:note` style for metadata is deleted.

See also: [`metadata`](@ref), [`metadatakeys`](@ref),
[`metadata!`](@ref), [`emptymetadata!`](@ref),
[`colmetadata`](@ref), [`colmetadatakeys`](@ref), [`colmetadata!`](@ref),
[`deletecolmetadata!`](@ref), [`emptycolmetadata!`](@ref).

# Examples

```jldoctest
julia> df = DataFrame(a=1, b=2);

julia> metadatakeys(df)
()

julia> metadata!(df, "name", "example", style=:note);

julia> metadatakeys(df)
KeySet for a Dict{String, Tuple{Any, Any}} with 1 entry. Keys:
  "name"

julia> metadata(df, "name")
"example"

julia> deletemetadata!(df, "name");

julia> metadatakeys(df)
()
```
"""
function deletemetadata!(df::DataFrame, key::AbstractString)
    meta = getfield(df, :metadata)
    # if metadata is nothing or key is missing in metadata this is a no-op
    meta === nothing && return df
    delete!(meta, key)
    isempty(meta) && setfield!(df, :metadata, nothing)
    return df
end

"""
    deletemetadata!(df::AbstractDataFrame, key::AbstractString)
    deletemetadata!(dfr::DataFrameRow, key::AbstractString)
    deletemetadata!(dfc::DataFrameColumns, key::AbstractString)
    deletemetadata!(dfr::DataFrameRows, key::AbstractString)
    deletemetadata!(gdf::GroupedDataFrame, key::AbstractString)

Delete table level metadata from object `df` for key `key`.

For `SubDataFrame` and `DataFrameRow` only `:note` style for metadata is deleted.

See also: [`metadata`](@ref), [`metadatakeys`](@ref),
[`metadata!`](@ref), [`deletemetadata!`](@ref),
[`colmetadata`](@ref), [`colmetadatakeys`](@ref), [`colmetadata!`](@ref),
[`deletecolmetadata!`](@ref), [`emptycolmetadata!`](@ref).

# Examples

```jldoctest
julia> df = DataFrame(a=1, b=2);

julia> metadatakeys(df)
()

julia> metadata!(df, "name", "example", style=:note);

julia> metadatakeys(df)
KeySet for a Dict{String, Tuple{Any, Any}} with 1 entry. Keys:
  "name"

julia> metadata(df, "name")
"example"

julia> emptymetadata!(df);

julia> metadatakeys(df)
()
```
"""
function emptymetadata!(df::DataFrame)
    setfield!(df, :metadata, nothing)
    return df
end

"""
    colmetadata(df::AbstractDataFrame, col::ColumnIndex, key::AbstractString; style::Bool=false)
    colmetadata(dfr::DataFrameRow, col::ColumnIndex, key::AbstractString; style::Bool=false)
    colmetadata(dfc::DataFrameColumns, col::ColumnIndex, key::AbstractString; style::Bool=false)
    colmetadata(dfr::DataFrameRows, col::ColumnIndex, key::AbstractString; style::Bool=false)
    colmetadata(gdf::GroupedDataFrame, col::ColumnIndex, key::AbstractString; style::Bool=false)

Return column level metadata value associated with `df` for column `col` and key `key`.

`SubDataFrame` and `DataFrameRow` expose only `:note` style metadata of their parent.

See also: [`metadata`](@ref), [`metadatakeys`](@ref),
[`metadata!`](@ref), [`deletemetadata!`](@ref), [`emptymetadata!`](@ref),
[`colmetadatakeys`](@ref), [`colmetadata!`](@ref),
[`deletecolmetadata!`](@ref), [`emptycolmetadata!`](@ref).

# Examples

```jldoctest
julia> df = DataFrame(a=1, b=2);

julia> colmetadatakeys(df)
()

julia> colmetadata!(df, :a, "name", "example", style=:note);

julia> collect(colmetadatakeys(df))
1-element Vector{Pair{Symbol, Base.KeySet{String, Dict{String, Tuple{Any, Any}}}}}:
 :a => ["name"]

julia> colmetadata(df, :a, "name")
"example"
```
"""
function colmetadata(df::DataFrame, col::Int, key::AbstractString; style::Bool=false)
    idx = index(df)[col] # bounds checking
    cols_meta = getfield(df, :colmetadata)
    cols_meta === nothing && throw(KeyError("Metadata for column $col for key $key not found"))
    col_meta = cols_meta[idx]
    return style ? col_meta[key] : col_meta[key][1]

end

# here and similar definitions below are added to avoid against dispatch ambiguity
colmetadata(df::DataFrame, col::Symbol, key::AbstractString; style::Bool=false) =
    colmetadata(df, Int(index(df)[col]), key, style=style)
colmetadata(df::DataFrame, col::ColumnIndex, key::AbstractString; style::Bool=false) =
    colmetadata(df, Int(index(df)[col]), key, style=style)

"""
    colmetadatakeys(df::AbstractDataFrame, [col::ColumnIndex])
    colmetadatakeys(dfr::DataFrameRow, [col::ColumnIndex])
    colmetadatakeys(dfc::DataFrameColumns, [col::ColumnIndex])
    colmetadatakeys(dfr::DataFrameRows, [col::ColumnIndex])
    colmetadatakeys(gdf::GroupedDataFrame, [col::ColumnIndex])

If `col` is passed return an iterator of column level metadata keys for which
`metadata(x, col, key)` returns a metadata value.

`SubDataFrame` and `DataFrameRow` expose only `:note` style metadata of their parent.

If `col` is not passed return an iterator of `col => colmetadatakeys(x, col)`
pairs for all columns that have metadata.

See also: [`metadata`](@ref), [`metadatakeys`](@ref),
[`metadata!`](@ref), [`deletemetadata!`](@ref), [`emptymetadata!`](@ref),
[`colmetadata`](@ref), [`colmetadata!`](@ref),
[`deletecolmetadata!`](@ref), [`emptycolmetadata!`](@ref).

# Examples

```jldoctest
julia> df = DataFrame(a=1, b=2);

julia> colmetadatakeys(df)
()

julia> colmetadata!(df, :a, "name", "example", style=:note);

julia> collect(colmetadatakeys(df))
1-element Vector{Pair{Symbol, Base.KeySet{String, Dict{String, Tuple{Any, Any}}}}}:
 :a => ["name"]

julia> colmetadata(df, :a, "name")
"example"
```
"""
function colmetadatakeys(df::DataFrame, col::Int)
    idx = index(df)[col] # bounds checking
    cols_meta = getfield(df, :colmetadata)
    cols_meta === nothing && return ()
    haskey(cols_meta, idx) || return ()
    metakeys = keys(cols_meta[idx])
    @assert !isempty(metakeys) # by design in such cases meta === nothing should be met
    return metakeys
end

colmetadatakeys(df::DataFrame, col::Symbol) = colmetadatakes(df, Int(index(df)[col]))
colmetadatakeys(df::DataFrame, col::ColumnIndex) = colmetadatakes(df, Int(index(df)[col]))

function colmetadatakeys(df::DataFrame)
    cols_meta = getfield(df, :colmetadata)
    cols_meta === nothing && return ()
    return (_names(df)[idx] => colmetadatakeys(df, idx) for idx in keys(cols_meta))
end

"""
    colmetadata!(df::AbstractDataFrame, col::ColumnIndex, key::AbstractString, value; style)
    colmetadata!(dfr::DataFrameRow, col::ColumnIndex, key::AbstractString, value; style)
    colmetadata!(dfc::DataFrameColumns, col::ColumnIndex, key::AbstractString, value; style)
    colmetadata!(dfr::DataFrameRows, col::ColumnIndex, key::AbstractString, value; style)
    colmetadata!(gdf::GroupedDataFrame, col::ColumnIndex, key::AbstractString, value; style)

Set column level metadata for `df` for column `col` for key `key` to have value `value`
and style `style` and return `df`.

For `SubDataFrame` and `DataFrameRow` only `:note` style for metadata is allowed.
Trying to add key-value pair such that in the parent data frame already
mapping for key exists with `:none` style throws an error.

See also: [`metadata`](@ref), [`metadatakeys`](@ref),
[`metadata!`](@ref), [`deletemetadata!`](@ref), [`emptymetadata!`](@ref),
[`colmetadata`](@ref), [`colmetadatakeys`](@ref),
[`deletecolmetadata!`](@ref), [`emptycolmetadata!`](@ref).

# Examples

```jldoctest
julia> df = DataFrame(a=1, b=2);

julia> colmetadatakeys(df)
()

julia> colmetadata!(df, :a, "name", "example", style=:note);

julia> collect(colmetadatakeys(df))
1-element Vector{Pair{Symbol, Base.KeySet{String, Dict{String, Tuple{Any, Any}}}}}:
 :a => ["name"]

julia> colmetadata(df, :a, "name")
"example"
```
"""
function colmetadata!(df::DataFrame, col::Int, key::AbstractString, value::Any; style)
    idx = index(df)[col] # bounds checking
    pre_cols_meta = getfield(df, :colmetadata)
    if pre_cols_meta === nothing
        cols_meta = Dict{Int, Dict{String,Tuple{Any, Any}}}()
        setfield!(df, :colmetadata, cols_meta)
    else
        cols_meta = pre_cols_meta
    end
    col_meta = get!(Dict{String, Tuple{Any, Any}}, cols_meta, idx)
    col_meta[key] = (value, style)
    return df
end

colmetadata!(df::DataFrame, col::Symbol, key::AbstractString, value::Any; style) =
    colmetadata!(df, Int(index(df)[col]), key, value; style=style)
colmetadata!(df::DataFrame, col::ColumnIndex, key::AbstractString, value::Any; style) =
    colmetadata!(df, Int(index(df)[col]), key, value; style=style)

"""
    deletecolmetadata!(df::AbstractDataFrame, col::ColumnIndex, key::AbstractString)
    deletecolmetadata!(dfr::DataFrameRow, col::ColumnIndex, key::AbstractString)
    deletecolmetadata!(dfc::DataFrameColumns, col::ColumnIndex, key::AbstractString)
    deletecolmetadata!(dfr::DataFrameRows, col::ColumnIndex, key::AbstractString)
    deletecolmetadata!(gdf::GroupedDataFrame, col::ColumnIndex, key::AbstractString)

Delete column level metadata for `df` for column `col` for key `key` and return `df`.

For `SubDataFrame` and `DataFrameRow` only `:note` style for metadata is deleted.

See also: [`metadata`](@ref), [`metadatakeys`](@ref),
[`metadata!`](@ref), [`deletemetadata!`](@ref), [`emptymetadata!`](@ref),
[`colmetadata`](@ref), [`colmetadatakeys`](@ref),
[`colmetadata!`](@ref), [`emptycolmetadata!`](@ref).

# Examples

```jldoctest
julia> df = DataFrame(a=1, b=2);

julia> colmetadata!(df, :a, "name", "example", style=:note);

julia> collect(colmetadatakeys(df))
1-element Vector{Pair{Symbol, Base.KeySet{String, Dict{String, Tuple{Any, Any}}}}}:
 :a => ["name"]

julia> colmetadata(df, :a, "name")
"example"

julia> deletecolmetadata!(df, :a, "name");

julia> colmetadatakeys(df)
()
```
"""
function deletecolmetadata!(df::DataFrame, col::Int, key::AbstractString)
    idx = index(df)[col] # bounds checking
    cols_meta = getfield(df, :colmetadata)
    # if metadata is nothing or key is missing in metadata this is a no-op
    cols_meta === nothing && return df
    haskey(cols_meta, idx) || return df
    col_meta = cols_meta[idx]
    delete!(col_meta, key)
    isempty(col_meta) && delete!(cols_meta, idx)
    isempty(cols_meta) && setfield!(df, :colmetadata, nothing)
    return df
end

deletecolmetadata!(df::DataFrame, col::Symbol, key::AbstractString) =
    deletecolmetadata!(df, Int(index(df)[col]), key)
deletecolmetadata!(df::DataFrame, col::ColumnIndex, key::AbstractString) =
    deletecolmetadata!(df, Int(index(df)[col]), key)

"""
    emptycolmetadata!(df::AbstractDataFrame, col::ColumnIndex, key::AbstractString)
    emptycolmetadata!(dfr::DataFrameRow, col::ColumnIndex, key::AbstractString)
    emptycolmetadata!(dfc::DataFrameColumns, col::ColumnIndex, key::AbstractString)
    emptycolmetadata!(dfr::DataFrameRows, col::ColumnIndex, key::AbstractString)
    emptycolmetadata!(gdf::GroupedDataFrame, col::ColumnIndex, key::AbstractString)

Delete column level metadata for `df` for column `col` for key `key` and return `df`.

For `SubDataFrame` and `DataFrameRow` only `:note` style for metadata is deleted.

See also: [`metadata`](@ref), [`metadatakeys`](@ref),
[`metadata!`](@ref), [`deletemetadata!`](@ref), [`emptymetadata!`](@ref),
[`colmetadata`](@ref), [`colmetadatakeys`](@ref),
[`colmetadata!`](@ref), [`deletecolmetadata!`](@ref).

# Examples

```jldoctest
julia> df = DataFrame(a=1, b=2);

julia> colmetadata!(df, :a, "name", "example", style=:note);

julia> collect(colmetadatakeys(df))
1-element Vector{Pair{Symbol, Base.KeySet{String, Dict{String, Tuple{Any, Any}}}}}:
 :a => ["name"]

julia> colmetadata(df, :a, "name")
"example"

julia> emptycolmetadata!(df, :a);

julia> colmetadatakeys(df)
()
```
"""
function emptycolmetadata!(df::DataFrame, col::Int)
    idx = index(df)[col] # bounds checking
    cols_meta = getfield(df, :colmetadata)
    cols_meta === nothing && return df
    delete!(cols_meta, idx)
    isempty(cols_meta) && setfield!(df, :colmetadata, nothing)
    return df
end

emptycolmetadata!(df::DataFrame, col::Symbol) =
    emptycolmetadata!(df, Int(index(df)[col]))
emptycolmetadata!(df::DataFrame, col::ColumnIndex) =
    emptycolmetadata!(df, Int(index(df)[col]))

function emptycolmetadata!(df::DataFrame)
    setfield!(df, :colmetadata, nothing)
    return df
end






_drop_metadata!(df::DataFrame) = setfield!(df, :metadata, nothing)
_drop_colmetadata!(df::DataFrame) = setfield!(df, :colmetadata, nothing)

function _drop_colmetadata!(df::AbstractDataFrame, col::ColumnIndex)
    colmetadata = getfield(parent(df), :colmetadata)
    if colmetadata !== nothing
        delete!(colmetadata, index(df)[col])
    end
    return nothing
end

function _copy_metadata!(dst::DataFrame, src)
    if hasmetadata(src) === true
        copy!(metadata(dst), metadata(src))
    else
        _drop_metadata!(dst)
    end
    return nothing
end

function _copy_colmetadata!(dst::AbstractDataFrame, dstcol::ColumnIndex,
                            src, srccol::ColumnIndex)
    if hascolmetadata(src, srccol) === true
        copy!(colmetadata(dst, dstcol), colmetadata(src, srccol))
    else
        _drop_colmetadata!(dst, dstcol)
    end
    return nothing
end

# this is a function used to copy metadata
# to a freshly allocated dst without metadata where column names
# in dst is a subset of column names in src
function _unsafe_copy_all_metadata!(dst::DataFrame, src::AbstractDataFrame)
    _copy_metadata!(dst, src)
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

function _merge_matching_df_metadata!(res::DataFrame, dfs)
    # only table level metadata is merged
    if !isempty(dfs) && all(x -> hasmetadata(x), dfs)
        all_meta = Dict{String,Any}[metadata(df) for df in dfs]
        if length(all_meta) == 1
            _copy_metadata!(res, only(dfs))
        else
            new_meta = Dict{String, Any}()
            for (k, v) in pairs(all_meta[1])
                if all(@view all_meta[2:end]) do this_meta
                    return isequal(get(this_meta, k, _MetadataMergeSentinelType()), v)
                end
                    new_meta[k] = v
                end
            end
            if !isempty(new_meta)
                copy!(metadata(res), new_meta)
            end
        end
    end
end

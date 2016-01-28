#################### Sampler ####################

const samplerfxargs = [(:model, :Model), (:block, :Integer)]


#################### Types and Constructors ####################

type SamplingBlock
  model::Model
  index::Int
  transform::Bool

  SamplingBlock(model::Model, index::Integer=0, transform::Bool=false) =
    new(model, index, transform)
end


Sampler(param::Symbol, args...) = Sampler([param], args...)

function Sampler(params::Vector{Symbol}, f::Function, tune::Any=Dict())
  Sampler(params, modelfx(samplerfxargs, f), tune, Symbol[])
end


function SamplerVariate{T<:SamplerTune, U<:Real}(x::AbstractVector{U}, tune::T)
  SamplerVariate{T}(x, tune)
end

function SamplerVariate(block::SamplingBlock, pargs...; kargs...)
  m = block.model
  SamplerVariate(unlist(block), m.samplers[block.index], m.iter, pargs...;
                 kargs...)
end

function SamplerVariate{T<:SamplerTune, U<:Real}(x::AbstractVector{U},
                                                 s::Sampler{T}, iter::Integer,
                                                 pargs...; kargs...)
  if iter == 1
    v = SamplerVariate{T}(x, pargs...; kargs...)
    s.tune = v.tune
  else
    v = SamplerVariate(x, s.tune)
  end
  v
end


#################### Variate Validators ####################

validate(v::SamplerVariate) = v

macro validatebinary(V)
  esc(quote
        function validate(v::$V)
          all(insupport(Bernoulli, v)) ||
            throw(ArgumentError("variate is not a binary vector"))
          v
        end
      end)
end

macro validatesimplex(V)
  esc(quote
        function validate(v::$V)
          isprobvec(v) ||
            throw(ArgumentError("variate is not a probability vector"))
          v
        end
      end)
end


#################### Base Methods ####################

function Base.show(io::IO, s::Sampler)
  print(io, "An object of type \"$(summary(s))\"\n")
  print(io, "Sampling Block Nodes:\n")
  show(io, s.params)
  print(io, "\n\n")
  show(io, s.eval.code)
  println(io)
end

function Base.showall(io::IO, s::Sampler)
  show(io, s)
  print(io, "\nTuning Parameters:\n")
  show(io, s.tune)
  print(io, "\n\nTarget Nodes:\n")
  show(io, s.targets)
end


#################### Simulation Methods ####################

function gradlogpdf!{T<:Real}(block::SamplingBlock, x::AbstractArray{T},
                              dtype::Symbol=:forward)
  gradlogpdf!(block.model, x, block.index, block.transform, dtype=dtype)
end

function logpdf!{T<:Real}(block::SamplingBlock, x::AbstractArray{T})
  logpdf!(block.model, x, block.index, block.transform)
end

function logpdfgrad!{T<:Real}(block::SamplingBlock, x::AbstractVector{T},
                              dtype::Symbol)
  grad = gradlogpdf!(block, x, dtype)
  logf = logpdf!(block, x)
  (logf, ifelse(isfinite(grad), grad, 0.0))
end

function unlist(block::SamplingBlock)
  unlist(block.model, block.index, block.transform)
end

function relist{T<:Real}(block::SamplingBlock, x::AbstractArray{T})
  relist(block.model, x, block.index, block.transform)
end


#################### Auxiliary Functions ####################

asvec(x::Union{Number, Symbol}) = [x]
asvec(x::Vector) = x

function logpdfgrad{T<:Real}(m::Model, x::AbstractVector{T}, block::Integer,
                             dtype::Symbol)
  logf = logpdf(m, x, block, true)
  grad = isfinite(logf) ?
           gradlogpdf(m, x, block, true, dtype=dtype) :
           zeros(x)
  logf, grad
end

function logpdfgrad!{T<:Real}(m::Model, x::AbstractVector{T}, block::Integer,
                              dtype::Symbol)
  logf = logpdf!(m, x, block, true)
  grad = isfinite(logf) ?
           gradlogpdf!(m, x, block, true, dtype=dtype) :
           zeros(length(x))
  logf, grad


#################### Legacy Sampler Code ####################

function SamplerVariate(m::Model, block::Integer, transform::Bool=false)
  SamplerVariate(unlist(m, block, transform), m.samplers[block], m.iter)
end

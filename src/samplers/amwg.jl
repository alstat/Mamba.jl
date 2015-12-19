#################### Adaptive Metropolis within Gibbs ####################

#################### Types and Constructors ####################

type AMWGTune <: SamplerTune
  adapt::Bool
  accept::Vector{Int}
  batchsize::Int
  m::Int
  sigma::Vector{Float64}
  target::Real

  function AMWGTune(value::Vector{Float64}=Float64[])
    new(
      false,
      zeros(Int, length(value)),
      50,
      0,
      Array(Float64, 0),
      0.44
    )
  end
end


typealias AMWGVariate SamplerVariate{AMWGTune}


#################### Sampler Constructor ####################

function AMWG{T<:Real}(params::ElementOrVector{Symbol},
                       sigma::ElementOrVector{T}; adapt::Symbol=:all,
                       batchsize::Integer=50, target::Real=0.44)
  adapt in [:all, :burnin, :none] ||
    throw(ArgumentError("adapt must be one of :all, :burnin, or :none"))

  samplerfx = function(model::Model, block::Integer)
    v = SamplerVariate(model, block, true)
    if model.iter == 1 && isa(sigma, Real)
      sigma = fill(sigma, length(v))
    end
    f = x -> logpdf!(model, x, block, true)
    isadapt = adapt == :burnin ? model.iter <= model.burnin :
              adapt == :all ? true : false
    amwg!(v, sigma, f, adapt=isadapt, batchsize=batchsize, target=target)
    relist(model, v, block, true)
  end
  Sampler(params, samplerfx, AMWGTune())
end


#################### Sampling Functions ####################

function amwg!{T<:Real}(v::AMWGVariate, sigma::Vector{T}, logf::Function;
                        adapt::Bool=true, batchsize::Integer=50,
                        target::Real=0.44)
  tune = v.tune

  if adapt
    if !tune.adapt
      tune.adapt = true
      tune.accept[:] = 0
      tune.batchsize = batchsize
      tune.m = 0
      tune.sigma = copy(sigma)
      tune.target = target
    end
    tune.m += 1
    amwg_sub!(v, logf)
    if tune.m % tune.batchsize == 0
      delta = min(0.01, (tune.m / tune.batchsize)^-0.5)
      for i in 1:length(tune.sigma)
        epsilon = tune.accept[i] / tune.m < tune.target ? -delta : delta
        tune.sigma[i] *= exp(epsilon)
      end
    end
  else
    if !tune.adapt
      tune.sigma = sigma
    end
    amwg_sub!(v, logf)
  end

  v
end


function amwg_sub!(v::AMWGVariate, logf::Function)
  logf0 = logf(v.value)
  n = length(v)
  z = v.tune.sigma .* randn(n)
  for i in 1:n
    x = v[i]
    v[i] += z[i]
    logfprime = logf(v.value)
    if rand() < exp(logfprime - logf0)
      logf0 = logfprime
      v.tune.accept[i] += v.tune.adapt
    else
      v[i] = x
    end
  end
  v
end

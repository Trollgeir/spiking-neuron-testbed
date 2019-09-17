module network.randNormal;
import std.traits;
import std.math : E, log;

// Generates normally distributed random values.
T randNormal(T)(float mu_ = 0.0, float sigma_ = 1.0, float min = 0.0, float max = 1) if(isFloatingPoint!T)
{
	import std.stdio;
	assert(min <= mu_);
	assert(max >= mu_);
	// When x and y are two variables from [0, 1], uniformly distributed, then
	// cos(2*pi*x)*sqrt(-2*log(1-y)) and
	// sin(2*pi*x)*sqrt(-2*log(1-y))
	// are two independent variables with normal distribution (mu = 0, sigma = 1).
	// (Lambert Meertens)
	
	import std.random: uniform; // NOTE optimization: c.rand is loads faster
	import std.math: isnan, sqrt, log, sin, cos, PI;

	static T gauss_next; // nan
	auto z = gauss_next;
	gauss_next = T.init; // nan
	
	if(isnan(z))
	{
		T x2pi = uniform(0.0, 1.0)  * PI * 2.0;
		T g2rad = sqrt(-2.0 * log(1.0 - uniform(0.0, 1.0)));
		z = cos( x2pi ) * g2rad;
		gauss_next = sin( x2pi ) * g2rad;
	}

	float toReturn = mu_ + z * sigma_;

	if (toReturn < min)
	{
		toReturn = min;
	}

	if (toReturn > max)
	{
		toReturn = max;
	}
	return toReturn;
}

float sigmoid(float input)
{
	return (1 / (1 + E^^-input));
}

float rSigmoid(float input)
{
	return log(input/(1-input));
}
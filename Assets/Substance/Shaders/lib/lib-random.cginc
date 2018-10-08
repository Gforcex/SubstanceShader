//Return the ith number from fibonacci sequence.
float fibonacci1D(int i)
{
	return frac((float(i) + 1.0) * M_GOLDEN_RATIO);
}


//Return the ith couple from the fibonacci sequence.nbSample is required to get an uniform distribution.
float2 fibonacci2D(int i, int nbSamples)
{
	return float2(
		(float(i) + 0.5) / float(nbSamples),
		fibonacci1D(i)
	);
}
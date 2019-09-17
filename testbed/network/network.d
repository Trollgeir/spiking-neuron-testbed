module network.network;
import std.stdio;
import std.math;
import std.random : uniform;
import std.algorithm : sum;
import std.file;
import framework.test : Settings;
import main : BGE;

//Network configuration
struct NetConf
{
	size_t inputs;
	size_t[] hidden;
	size_t outputs;
}

class SNN
{

	size_t[] _layers;			//Neurons per layer
	size_t _neuron_c;
	float[] outputBuffer;


	float[] _membranes;			//Property of neuron: current membrane potential
	float[] _thresholds;		//Property of neuron: current membrane threshold

	float[][] weights;		//Property of neuron: weights of extending connections
	float[]	 mDecay;
	float[]	 tDecay;
	enum float equilibrium = 0.5f;
	float fitness = 0;
	bool[] outputs;
	float[] inputs;
	float[] _inputEquil;
	float reflex;

	bool[] _spikes;

	this(NetConf netConfig_)
	{
		_layers.length = 2+netConfig_.hidden.length;
		_layers[0] = netConfig_.inputs;
		foreach (i,layer_c; netConfig_.hidden) {
			_layers[i+1] = layer_c;
		}
		_layers[$-1] = netConfig_.outputs;
		outputBuffer.length = netConfig_.outputs;
		_neuron_c = sum(_layers.dup);
		_membranes.length = _thresholds.length = mDecay.length = tDecay.length = _spikes.length = _neuron_c;
		weights.length = _neuron_c;

		outputs.length = netConfig_.outputs;
		inputs.length = netConfig_.inputs;
//		inputMembranes = _membranes[0 .. netConfig_.inputs];
		_inputEquil.length = inputs.length;

		size_t shift;
		foreach(i,layerCount; _layers)
		{
			if(i == _layers.length-1)
			{
				foreach(ref weight; weights[shift .. layerCount+shift])
					weight.length = _layers[i-1];
			}
			else
			{
				foreach(ref weight; weights[shift .. layerCount+shift])
					weight.length = _layers[i+1];
				shift += layerCount;
			}
		}
		flush;
	}

	void randomize()
	{
		reflex = uniform(-1f,1f);
		foreach (i; 0 .. _neuron_c) {
//			mDecay[i] = 1 - uniform(0f,1f)^^2;
			if (uniform(0,2))
				mDecay[i] = uniform(0f,1f);
			else
				if (uniform(0,2)) 
					mDecay[i] = 0f;
				else
					mDecay[i] = 1f;

			if (uniform(0,2))
				tDecay[i] = uniform(0f,1f);
			else
				if (uniform(0,2)) 
					tDecay[i] = 0f;
				else
					tDecay[i] = 1f;
		}

		foreach(i,weightArray; weights) {
			if(i > _neuron_c - outputs.length)
			{
				weightArray[] = 0;
			}
			else
			{
				foreach (ref weight; weightArray) 
				{
					if (uniform(0,2)) 
						weight = uniform(-1f,1f);
					else
						weight = 0f;
				}
			}
		}

		foreach(ref e; _inputEquil) {
			if (uniform(0,2))
				e = uniform(0f,1f);
			else
				e = 0f;
		}
		flush;
	}

	void tick(Settings* settings)
	{
		outputBuffer[] = 0;
		outputs[] = 0;
		foreach(k; 0 .. settings.ticksPerUpdate)
		{
			_spikes[] = false;
			//changing rounding to zero, else we'll get a massive performance penalty.
			FloatingPointControl fpctrl;
			fpctrl.rounding = FloatingPointControl.roundToZero;

			//Our current Neuron Index:
			size_t nIdx;

			//Processing Input layer:
			{
				size_t shift = _layers[0];			//find the index of the first neuron in the next layer
				foreach(i; nIdx .. shift) {		//for each neuron in our current layer .
					import std.math : isNaN;
					import std.conv : to;
					assert(!_membranes[i].isNaN, to!string(i));
					assert(!_thresholds[i].isNaN, to!string(i));
					_membranes[i] += inputs[i];
					if (_membranes[i] > _thresholds[i]) {
						_thresholds[i] += _membranes[i] * tDecay[i];
						_membranes[i] = 0;
						_spikes[i] = true;
						foreach(j,weight; weights[i]) {
							_membranes[shift+j] += weight; 	//propagate to the neurons in the next layer
						}
					}
					else {
						_membranes[i] *= mDecay[i];
						_thresholds[i] += _membranes[i] * tDecay[i];
					}
					_thresholds[i] += ((_inputEquil[i] - _thresholds[i]) / 2) * tDecay[i];
				}
				nIdx += shift;
			}

			//Processing Hidden _layers
			foreach (layer_c; _layers[1 .. $-1]) {		//fetch how many neurons are in this layer, ignore last layer (output layer)
				size_t shift = nIdx+layer_c; 			//find the index of the first neuron in the next layer
				foreach(i; nIdx .. shift) {				//for each neuron in our current layer ..
					import std.math : isNaN;
					assert(!_membranes[i].isNaN);
					assert(!_thresholds[i].isNaN);
					if (_membranes[i] > _thresholds[i]) {	//If action potential..
						_thresholds[i] += _membranes[i] * tDecay[i];
						_membranes[i] = 0;
						_spikes[i] = true;

						foreach(j,weight; weights[i]) {
							_membranes[shift+j] += weight; //.. propagate to the neurons in the next layer
						}
					}
					else {
						_membranes[i] *= mDecay[i];
						_thresholds[i] += _membranes[i] * tDecay[i];
					}
					_thresholds[i] += ((equilibrium - _thresholds[i]) / 2) * tDecay[i];
				}
				nIdx += layer_c; 	//layer done, shifting neuron index to the start of the next layer.
			}

			size_t j;
			size_t shift = nIdx - _layers[$-2];
		//	Output layer:
			foreach (i; nIdx .. _neuron_c) {
					import std.math : isNaN;
					assert(!_membranes[i].isNaN);
					assert(!_thresholds[i].isNaN);
				if (_membranes[i] > _thresholds[i]) {
					_thresholds[i] += _membranes[i] * tDecay[i];
					_membranes[i] = 0f;
					_spikes[i] = true;

					if(settings.recurrent)
					{
						foreach(y,weight; weights[i]) {
							_membranes[shift+y] += weight; //.. propagate back to the previous layer
						}
					}
					outputBuffer[j] += _spikes[i];
				}
				else {
					_membranes[i] *= mDecay[i];
					_thresholds[i] += _membranes[i] * tDecay[i];
				}
				_thresholds[i] += ((equilibrium - _thresholds[i]) / 2) * tDecay[i];
				++j;
			}
		}
		outputBuffer[] /= settings.ticksPerUpdate;
		foreach(i,ref value; outputBuffer)
		{
			if (value > 0)
				outputs[i] = true;
		}
		inputs[] = 0;
	}


	void flush()
	{
		foreach(i,equil; _inputEquil) {
			_thresholds[i] = equil;
		}
		_thresholds[_inputEquil.length .. $] = equilibrium;

		_membranes[] = 0;
//		fitness = 0;
		outputs[] = 0;
		inputs[] = 0;
	}

	typeof(this) dup()
	{
		SNN n = new SNN(NetConf(_layers[0], _layers[1 .. $-1], _layers[$-1]));

		n.mDecay[] = this.mDecay.dup;
		n.tDecay[] = this.tDecay.dup;
		n._inputEquil[] = this._inputEquil.dup;

		foreach (i,ref weight; n.weights) {
			weight[] = this.weights[i].dup;
		}
		n.reflex = this.reflex;
		n.flush;
		return n;
	}

	void info()
	{
		foreach(weight; weights) {
			writeln(weights);
		}
	}

	string neuronInfo(size_t idx)
	{
		import std.conv : to;
		string toReturn;
		if(idx < inputs.length) toReturn ~= "network._inputEquil["~to!string(idx)~"] = "~to!string(_inputEquil[idx])~";\n";
		toReturn ~= "network.mDecay["~to!string(idx)~"] = "~to!string(mDecay[idx])~";\n";
		toReturn ~= "network.tDecay["~to!string(idx)~"] = "~to!string(tDecay[idx])~";\n";
		toReturn ~= "network.weights["~to!string(idx)~"] = "~to!string(weights[idx])~";\n";
		return toReturn;
	}

}

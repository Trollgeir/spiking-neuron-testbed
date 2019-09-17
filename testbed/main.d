module main;

import network.training;
import framework.test: Settings;
import framework.render;
import core.thread;

BGEvolution BGE;
Settings settings;
Thread evolutionThread;


void main()
{
	import std.parallelism;
//	defaultPoolThreads(totalCPUs - 6);
	BGE = new BGEvolution();
	evolutionThread = new Thread(&BGE.evolve);
	render();

//	BGE.evolve();
} 
 
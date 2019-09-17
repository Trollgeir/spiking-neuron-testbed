module network.training;
import network.network;
import network.randNormal;
import std.algorithm;
import std.stdio;
import std.random;
import std.parallelism;
import framework.test;
import tests.test_entries;
import deimos.glfw.glfw3;
import framework.render : mainWindow;
import logging.plotlystreamer;
import dbox;

//Population size
enum popSize = 100; 


class BGEvolution
{
	plotlyStreamer stream;
	Settings* settings;
	Spawn[] globalSpawns;
	Population pop;
	SNN sampleNetwork;
	float bestFitness;
	bool sampleReady = false;
	size_t trial;
	bool stopFlag;
	bool useStream = true;

	this()
	{
		settings = &main.settings;
		if(useStream)
		{
			stream = new plotlyStreamer("v5q2emjeve");
			stream.connect();
		}
	}

	SNN getSample()
	{
		if(sampleReady)
			return sampleNetwork.dup;
		else
		{
			import core.thread;
			Thread.sleep(100.msecs);
			return getSample();
		}
		assert(0);
	}

	void evolve()
	{
		float lastHz;
		bool lastIF;
		size_t lastSignalIdx;
		float lastFoodRadius;

		while(!stopFlag)
		{
			import framework.render;
			auto activeSelection = testSelection;
			auto entry = &g_testEntries[testSelection];
//			import tests.navigate : Navigate;
//			NeuralTest test = new Navigate!(mode.cpu);
//			if (entry.name == "StressTest") {
//				writeln("No evolution in stress test");
//				while (activeSelection == testSelection) {
//					import core.thread;
//					Thread.sleep(100.msecs);
//				}
//				entry = &g_testEntries[testSelection];
//			}

//			writefln("Evolving a population in test \"%s\"", entry.name);
			NetConf netConfig = entry.getNetConf();
			writeln("Constructing networks..");
			pop = new Population(netConfig);
			settings.newGen = false;

			{
				size_t accu;
				if(netConfig.hidden.length > 0)
				{
					accu += netConfig.inputs*netConfig.hidden[0];
					if(netConfig.hidden.length > 1)
						for (size_t i; i < netConfig.hidden.length-1; ++i)
						{
							accu += netConfig.hidden[i] * netConfig.hidden[i+1];
						}
					accu += netConfig.hidden[$-1] * netConfig.outputs;
				}
				else {
					accu = netConfig.inputs * netConfig.outputs;
				}
//				settings.mutProb = accu;
			}
			//Erasing previous fitness data log
			if(useStream) stream.resetGraph;
			sampleNetwork = pop.networks[0].dup;
			sampleReady = true;

			while(sampleReady) {
				if (settings.pauseEvo) {
					writeln("Evolution paused ..");
					import core.memory;
					GC.enable;
					while(settings.pauseEvo == true) {
						import core.thread;
						Thread.sleep(100.msecs);
						if(useStream) stream.keepAlive();
					}
					GC.disable;
				}
				globalSpawns = entry.createSpwn(settings);


				// Checking for altered settings
				bool retrainElite;
				if (lastHz != settings.hz || lastSignalIdx != settings.signalIdx || settings.IF != lastIF || lastFoodRadius != settings.foodRadius)
					retrainElite = true;
				lastHz = settings.hz;
				lastIF = settings.IF;
				lastSignalIdx = settings.signalIdx;
				lastFoodRadius = settings.foodRadius;

				//Disabling GC
				import core.memory;
				GC.disable;

				// If test doesn't return any global spawns, the test will make its own static spawns
				if (globalSpawns is null && settings.eliteSize && !retrainElite)
				{
					foreach(network; parallel(pop.networks[settings.eliteSize .. $],1)) {
						NeuralTest world = entry.createCpuFcn();
						world.network = network;
						world.settings = settings;
						world.performTest();
					}
				}
				else 
				{
					if(settings.bestNetwork)
					{
						NeuralTest world = entry.createCpuFcn();
						world.network = pop.networks[0];
						world.spawns = globalSpawns.dup;
						world.settings = settings;
						world.performTest();
					}
					else
					{
						int numTrials = 1;
						foreach(i; 0 .. numTrials)
						{
							foreach(network; parallel(pop.networks[],1)) {
								NeuralTest world = entry.createCpuFcn();
								network.flush;
								world.network = network;
								world.spawns = globalSpawns.dup;
								world.settings = settings;
								world.performTest();
							}
							if(settings.bestNetwork) break;
							stream.keepAlive();
							globalSpawns = entry.createSpwn(settings);
						}
						foreach(network; pop.networks)
							network.fitness /= numTrials;
					}
					retrainElite = false;
				}
				GC.collect;
				pop.train();
				sampleNetwork = pop.networks[0].dup;

			}
		}
	}

	class Population
	{
		SNN[popSize] networks;
		NetConf _netConfig;
		
		size_t generationCount;
		float accFitLogData = 0f;
		float[] fitness;
		double lastTime;
		double time;

		
		this(NetConf netConfig_)
		{
			_netConfig = netConfig_;
			foreach(i,ref individual; networks) {
				individual = new SNN(_netConfig);
				individual.randomize;
			}
		}
		
		struct Pairings
		{
			size_t[popSize] a;
			size_t[popSize] b;
		}
		
		Pairings SUS(float[] fitnesses)
		{
			assert(fitnesses.length == popSize);
			Pairings finalPairs;
			float totalFitness = sum(fitnesses);
			float distance = totalFitness / 2f;
			
			//repair function
			if (distance <= 0) {
				writeln("Warning: No fitness! Randomizing parents..");
				foreach (i; 0 .. finalPairs.a.length) {
					finalPairs.a[i] = uniform(0,finalPairs.a.length);
					finalPairs.b[i] = uniform(0,finalPairs.b.length);
				}
				return finalPairs;
			}
			foreach(i; 0 .. finalPairs.a.length) {
				
				float a = uniform(0f,distance);
				float b = a + distance;
				
				size_t j;
				while (sum(fitnesses[0..j+1]) < a) {
					++j;
				}
				finalPairs.a[i] = j;
	
				j = 0;
				while (j != popSize && sum(fitnesses[0..j+1]) < b) {
					++j;
				}
				finalPairs.b[i] = j;
			}
			return finalPairs;
		}
		
		SNN crossMutate(size_t a, size_t b)
		{
			enum size_t nonGaussProb = 2;
			SNN offspring = new SNN(_netConfig);

			foreach (i; 0 .. networks[a].mDecay.length) {
				size_t n = (uniform(0,2) == true) ? a : b;
//				n = a;

				offspring.mDecay[i] = networks[n].mDecay[i];

				offspring.reflex = networks[n].reflex;
				if (!cast(bool)(uniform(0,settings.mutProb))) {
					if(uniform(0,nonGaussProb))
						offspring.reflex = randNormal!float(offspring.reflex,0.05,-1f,1f);
					else
					{
						offspring.reflex = uniform(-1f,1f);
					}	
				}

				if (!cast(bool)uniform(0,settings.mutProb))
				{
					if(uniform(0,nonGaussProb)) {
						offspring.mDecay[i] = randNormal!float(offspring.mDecay[i],0.05);
					}
					else {
						if (uniform(0,2)) 
							offspring.mDecay[i] = uniform(0f,1f);
						else 
							if (uniform(0,2)) 
								offspring.mDecay[i] = 0f;
							else
								offspring.mDecay[i] = 1f;
					}
				}

				offspring.tDecay[i] = networks[n].tDecay[i];

				if (!cast(bool)uniform(0,settings.mutProb)) {
					if(uniform(0,nonGaussProb)) {
						offspring.tDecay[i] = randNormal!float(offspring.tDecay[i],0.05);
					}
					else {
						if (uniform(0,2)) 
							offspring.tDecay[i] = uniform(0f,1f);
						else 
							if (uniform(0,2)) 
								offspring.tDecay[i] = 0f;
							else
								offspring.tDecay[i] = 1f;
					}
				}

				if (i < offspring.weights.length) {
					offspring.weights[i] = networks[n].weights[i].dup;
				
					foreach (ref weight; offspring.weights[i]) {
						if (!cast(bool)(uniform(0,settings.mutProb))) {
							if(uniform(0,nonGaussProb))
								weight = randNormal!float(weight,0.05,-1f,1f);
							else
							{
								if (uniform(0,2)) 
									weight = uniform(-1f,1f);
								else 
									weight = 0;
							}	
						}
					}
				}
				
				if (i < offspring._inputEquil.length) {
					offspring._inputEquil[i] = networks[n]._inputEquil[i];
					
					if (!cast(bool)(uniform(0,settings.mutProb))) {
						if(uniform(0,nonGaussProb))
							offspring._inputEquil[i] = randNormal!float(offspring._inputEquil[i],0.05);
						else 
							if (uniform(0,2))
								offspring._inputEquil[i] = uniform(0f,1f);
							else
								offspring._inputEquil[i] = 0;
					}
				}
			}

			offspring.flush;

			return offspring;
		}
		
		void train()
		{
			float lbe = networks[0].fitness;
			sort!("a.fitness > b.fitness")(networks[]);
			
			float avgO = 0;
			float avgE = 0;
			fitness.length = networks.length;
			foreach(i,network; networks) 
			{
				if (i < settings.eliteSize)
					avgE += network.fitness;
				else
					avgO += network.fitness;

				fitness[i] = network.fitness;
			}

			avgO /= networks.length - settings.eliteSize;
			avgE /= settings.eliteSize;
													
			import deimos.glfw.glfw3;
			
			time = glfwGetTime() - lastTime;
			lastTime = glfwGetTime();

			bestFitness = networks[0].fitness;

			writefln("Gen %s \t t=%s \t OF: %s \t\t EF: %s \t\t BE: %s \t\t LBE: %s",generationCount, time, avgO, avgE, bestFitness,lbe);
			
			Pairings pairs = SUS(fitness);
			
			SNN[popSize] offspring;
	
			foreach(i; 0 .. settings.eliteSize) {
				offspring[i] = networks[i];
				offspring[i].fitness = 0;
				// Only flush if the NeuralTest doesn't have a dynamic environment as we want to keep the fitness
				if (globalSpawns !is null) offspring[i].flush;
			}

			foreach(i,ref o; offspring[settings.eliteSize .. $]) 
			{
				o = crossMutate(pairs.a[i],pairs.b[i]);
			}

			networks = offspring;

			accFitLogData += bestFitness;
			
			if (generationCount % 10 == 0) {
				accFitLogData /= 10;

				import std.algorithm : sum;
				
				// AVERAGE MEAN OVER 10
				static float[] avgBuffer;
				if (generationCount == 0) avgBuffer.length = 0;
				if (avgBuffer.length < 10)
					avgBuffer ~= accFitLogData;
				else
				{
					foreach(i,ref value; avgBuffer)
					{
						if (i == avgBuffer.length-1) 
							value = accFitLogData;
						else
							value = avgBuffer[i+1];
					}
				}
				float avgOverTen = sum(avgBuffer.dup) / avgBuffer.length;

				if(useStream) stream.sendXY(generationCount,avgOverTen);

				import std.file;
				import std.conv : to;
				import framework.render;

				File loggerFile;

//				if(g_testEntries[testSelection].name == "FG Segregation")
//				{
//					string tri = main.settings.triRay ? "triRay" : "oneRay";
//					loggerFile = File("CM-" ~ g_testEntries[testSelection].name ~ "-" ~ tri ~ "-" ~ to!string(trial) ~ ".dat","a");
//				}
//				else
//				loggerFile = File("CM-" ~ g_testEntries[testSelection].name ~ "-ONneuron-"~ to!string(trial) ~ ".dat","a");

//				loggerFile.writeln(avgOverTen);
//				loggerFile.close;

				accFitLogData = 0f;
			}
			++generationCount;

//			if(generationCount > 1000)
//			{
//				sampleReady = false;
//				++trial;
//				if(trial > 49)
//				{
//					stopFlag = true;
//					import framework.render;
//					auto entry = &g_testEntries[testSelection];
//					if(entry.name == "FG Segregation" && main.settings.triRay == true)
//						main.settings.triRay = false;
//					else
//						testSelection++;
//
//					if(testSelection > 0) stopFlag = true;
//						writeln("ALL TESTS DONE");
//
//					trial = 0;
//				}
//			}
		}
	}
}



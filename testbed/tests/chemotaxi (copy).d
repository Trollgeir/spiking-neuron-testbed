module tests.chemotaxiBACKUP;

import dbox.common;
import deimos.glfw.glfw3;
import framework.debug_draw;
import framework.test;
import tests.test_entries : mode;
import network.network;
import std.conv : to;
import std.stdio;

class Chemotaxi(mode m) : NeuralTest
{
	size_t foodCount;
	float boxDiminish;
	float32 creature_a;
	b2Vec2 creature_p;
	size_t sleepAllowance;
	size_t reward;

	enum totalFoodAmount = 10;
	enum foodDistance = 200;
	enum smellNeurons = 2;
	enum pacemaker = 1;

	this()
	{
		static if (m != m.cpu) {
			m_world.SetDebugDraw(g_debugDraw);
			network = BGE.getSample();
			spawns = createSpawns;
			settings = &main.settings;
			initialize;
		}
	}

	override void initialize()
	{
		reward = 4000;
		boxDiminish = reward * 0.1;	//diminshing returns for energy per food pickup
		sleepAllowance = 10;
		energy = reward;

		if(settings.helperParams)
		{
			network.mDecay[0] = 0f;
			network.tDecay[0] = 1f;
			network._inputEquil[0] = 0f;
		}
		
		if(settings.sensorClones)
		{
			network.mDecay[0..smellNeurons] = network.mDecay[0];
			network.tDecay[0..smellNeurons] = network.tDecay[0];
			network._inputEquil[0..smellNeurons] = network._inputEquil[0];
		}
		
		if(settings.motorClones)
		{
			network.mDecay[$ - network.outputs.length .. network._neuron_c] = network.mDecay[$ - network.outputs.length];
			network.tDecay[$ - network.outputs.length .. network._neuron_c] = network.tDecay[$ - network.outputs.length];
		}

		if(settings.paceMaker && pacemaker > 0)
		{
			network.tDecay[network.inputs.length-1] = 0;
			network.mDecay[network.inputs.length-1] = 0;
			network._inputEquil[network.inputs.length-1] = 0;
		}

		if(settings.IF)
			network.tDecay[] = 0;

		if(settings.bestNetwork)
		{
			// 2,[2],2
			if(getNetConf.hidden.length > 0)
			{
				network._inputEquil[0] = 0;
				network._inputEquil[1] = 0;

				network.mDecay[0] = 0;
				network.mDecay[1] = 0;
				network.mDecay[1] = 1;
				network.mDecay[2] = 0.534898;
				network.mDecay[3] = 0.620054;
				network.mDecay[4] = 1;

				network.tDecay[0] = 1;
				network.tDecay[1] = 0;
				network.tDecay[1] = 0.832974;
				network.tDecay[2] = 0.0685197;
				network.tDecay[3] = 0;
				network.tDecay[4] = 0.874944;

				network.weights[0] = [-0.564326, -0.503902];
				network.weights[1] = [-1, 0];
				network.weights[1] = [-0.129042, 0.502216];
				network.weights[2] = [0.698263, -0.861165];
				network.weights[3] = [0.346493, 0.858095];
				network.weights[4] = [-0.0324358, -0.159166];
			}
			else
			{
			// 2,[],2

			network._inputEquil[0] = 0;
			network._inputEquil[1] = 0;
			
			network.mDecay[0] = 0.222876;
			network.mDecay[1] = 0.222876;
			network.mDecay[2] = 0.972236;
			network.mDecay[3] = 0.531101;

			
			network.tDecay[0] = 1;
			network.tDecay[1] = 1;
			network.tDecay[2] = 0.917932;
			network.tDecay[3] = 0.0790275;

			
			network.weights[0] = [-0.359069, -0.509847];
			network.weights[1] = [-0.815264, 0];
			network.weights[2] = [0.0461097, -0.699302];
			network.weights[3] = [0.921058, -0.424542];
			}
		}

	}


	//Main step loop.
	override void Step(Settings* settings)
	{
		super.Step(settings);
		static if (m != m.user) {
			if (!m_body.IsAwake) {
				++sleepCounter;
			}
			else {
				sleepCounter = 0;
			}
		}

		float smellStrength = 0;
		float closest = float.max;
		size_t[] toBeRemoved;

		import std.algorithm : remove;

		float smellSense = 0;
		{
			auto ca =  m_body.GetAngle;
			auto cp = m_body.GetPosition;
			import core.stdc.math;
			float32 a = ca + (1.5)*(b2_pi);
			b2Vec2 p;
			p = cp + b2Vec2((settings.antLength) * cosf(a), (settings.antLength) * sinf(a));

			foreach(i,spawn; spawns)
			{
				float overlap = b2Distance(spawn,m_body.GetWorldCenter);
				if (overlap < settings.foodRadius+0.5) {
					++foodCount;
					network.fitness += 1;
					auto toReward = (foodCount*boxDiminish);
					if(toReward < reward)
						energy += reward - toReward;
					
					toBeRemoved ~= i;
					continue;
				}
				float smellDist = b2Distance(spawn,p);
				if (smellDist < closest)
					closest = smellDist;
			}
			
			smellSense = closest;

			import std.math : E, pow, sqrt;
			auto temp1 = pow(smellSense,2.5f);
			auto temp2 = pow((2 * (foodDistance)),2.5f) / 10;
			smellSense = pow(E,-(temp1/temp2));
			if (smellSense > 0)
				smellStrength += smellSense;
			
			if(closest < 100)
			{
				closest = 1 - (closest / 100);
				bestProx = closest;
			}
			else
				bestProx = 0;
			
			import network.randNormal : randNormal;
			if(settings.noise > 0)
				smellStrength = randNormal!float(smellStrength,settings.noise,-1f,1f);
			

			if(settings.onNeuron) 
			{
				network.inputs[0] += smellStrength;
				static if (m != m.cpu) {
					g_debugDraw.DrawSegment(cp,p,b2Color(1,1,1));
					if (network._spikes[0] > 0)
						g_debugDraw.DrawSolidCircle(p, 0.25f, b2Vec2(), b2Color(0f, 255f, 0f,255f));
				}
			}

			if(settings.offNeuron && smellNeurons > 1)
			{
				network.inputs[1] += 1 - smellStrength;
				static if (m != m.cpu) {
					g_debugDraw.DrawSegment(cp,p,b2Color(1,1,1));
					if (network._spikes[1] > 0)
						g_debugDraw.DrawSolidCircle(p, 0.25f, b2Vec2(), b2Color(255f, 0f, 0f,255f));
				}
			}
		}

	

		network.tick(settings.ticksPerUpdate,settings.recurrent);
		energy -= 1;


		if (network.outputs[0]) {
			b2Vec2 f = m_body.GetWorldVector(b2Vec2(-0.5f, -10f));
			b2Vec2 p = m_body.GetWorldPoint(b2Vec2(0.0f, 3.0f));
			m_body.ApplyLinearImpulse(f,p,true);
			energy -= 5;
		}

		if (network.outputs[1]) {
			b2Vec2 f = m_body.GetWorldVector(b2Vec2(0.5f, -10f));
			b2Vec2 p = m_body.GetWorldPoint(b2Vec2(0.0f, 3.0f));
			m_body.ApplyLinearImpulse(f,p,true);
			energy -= 5;
		}

		static if (m != m.cpu) {

			if (settings.chaseCam) {
				g_camera.m_center = m_body.GetWorldCenter;
			}


			foreach(spawn; spawns)
			{
				g_debugDraw.DrawSolidCircle(spawn, settings.foodRadius, b2Vec2(), b2Color(0f, 255f, 0f, 255f));
			}


//			foreach(i; 0 .. foodCount) {
//				g_debugDraw.DrawSolidCircle(spawns[i], settings.foodRadius, b2Vec2(), b2Color(255f, 0f, 0f, 0.5f));
//				auto textPos = spawns[i];
//				textPos.x += 1;
//				textPos.y -= 1;
//				g_debugDraw.DrawString(textPos,to!string(i+1));
//			}

			trace ~= m_body.GetWorldCenter;

			b2Color heat = b2Color(0,1,0);

			foreach_reverse(i,t; trace) {
				g_debugDraw.DrawPoint(t, 2, heat);
				if (heat.g > 0) {
					heat.g -= 0.001;
					if (heat.r < 0.5) heat.r += 0.001;
				}
			}

			b2Vec2 creatureD = m_body.GetWorldCenter;
			creatureD.y -= 2f;
			creatureD.x -= 1f;
			if(!settings.infEnergy)
				g_debugDraw.DrawString(creatureD, to!string(energy));

			if (settings.drawOutputs) {
				creatureD.y -= 1;
				creatureD.x -= (network.outputs.length/2f) - 0.5f;
				foreach(outputValue; network.outputs) {
					++creatureD.x;
					g_debugDraw.DrawPoint(creatureD, 10.0f,  b2Color(outputValue, outputValue, outputValue)); //Input firing HUD
				}
			}

			if(settings.drawSensor)
			{
				struct temp
				{
					float _equil;
					bool _spike;
				}
				temp[] pairs;
				pairs.length = smellNeurons;
				foreach(i,equil_;network._inputEquil[0 .. smellNeurons]) {
					pairs[i]._equil = equil_;
					pairs[i]._spike = network._spikes[i];
				}

				import std.algorithm;

				sort!("a._equil < b._equil")(pairs[]);

				foreach(i,pair; pairs) {
					b2Vec2 center;
					center.y = g_camera.m_center.y - 24;
					center.x = g_camera.m_center.x - pairs.length/2 + i;
					g_debugDraw.DrawPoint(center, 15f, b2Color(pair._spike, pair._spike, pair._spike)); //Input firing HUD
					if(i == pairs.length-1)
					{
						import std.conv : to;
						string str = to!string(smellStrength);
						center.x += 1;
						g_debugDraw.DrawString(center, str);
					}
				}
			}
		}

		if(toBeRemoved.length > 0)
		{
			assert(spawns.length >= toBeRemoved.length);
			foreach(index; toBeRemoved)
			{
				spawns = remove(spawns,index);
				toBeRemoved[] -= 1;
			}
		}
//		if(spawns.length == 0)
//		{
//			network.fitness += energy;
//			done = true;
//		}

		static if (m == m.cpu) {
			if (energy <= 0 || (sleepCounter > sleepAllowance)) {
				if (bestProx > 0) {
					network.fitness += bestProx;
				}
				if (sleepCounter > sleepAllowance) {
					network.fitness = 0;
				}
				done = true;
			}
		}
		static if(m == m.render)
		{
			if(!settings.infEnergy)
				if (energy <= 0)
					done = true;
		}
	}

	static NeuralTest Create()
	{
		return new typeof(this);
	}

	static b2Vec2[] createSpawns()
	{
		b2Vec2[] toReturn;
		float range = 400;
		toReturn.length = totalFoodAmount;
		foreach(i,ref spawn; toReturn) {
			spawn.x = uniform(-range,range);
			spawn.y = uniform(-range,range);
		}
//		foreach(i,ref spawn; toReturn[totalFoodAmount .. $]) {
//		spawn.x = toReturn[i].x + uniform(0.1f,1f);
//		}

		return toReturn;
	}

	static NetConf getNetConf()
	{
		size_t outputs = 2;
		return NetConf(pacemaker+smellNeurons,[],outputs);
	}
}

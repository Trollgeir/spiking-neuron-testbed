module tests.chemotaxi;

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
	size_t sleepAllowance = 10;
	int reward = 7000;
	float discount = 0.8f;

	enum totalFoodAmount = 10;
	enum foodDistance = 400;
	enum smellNeurons = 1;
	enum pacemaker = 0;

	this()
	{
		static if (m != m.cpu) {
			m_world.SetDebugDraw(g_debugDraw);
			network = BGE.getSample();
			settings = &main.settings;
			spawns = createSpawns(settings);
			initialize;
		}
	}

	override void initialize()
	{
		settings.foodRadius = 5;
		energy = reward;

		if(settings.helperParams)
		{
			network.mDecay[0] = 0.333f;
			network.tDecay[0] = 1f;
			network._inputEquil[0] = 0;
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

//		if(pacemaker > 0)
//		{
//			network.tDecay[network.inputs.length-1] = 0;
//			network.mDecay[network.inputs.length-1] = 1;
//		}

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
				network.mDecay[1] = 0; //0.475129;
				network.mDecay[2] = 0.876913;
				network.mDecay[3] = 0;
				network.mDecay[4] = 0.346107;
				network.mDecay[5] = 0;

				network.tDecay[0] = 1;
				network.tDecay[1] = 1;
				network.tDecay[2] = 0.981198;
				network.tDecay[3] = 0.924545;
				network.tDecay[4] = 0.155488;
				network.tDecay[5] = 0.473154;

				network.weights[0] = [0.90386, 0.758089];
				network.weights[1] = [0, 0.852652];
				network.weights[2] = [0.81224, 0.644401];
				network.weights[3] = [0.697886, -0.86737];
				network.weights[4] = [0,0];
				network.weights[5] = [0.0467544, -0.00427933];
			}
			else
			{	
				// 1,[],2

				network.mDecay[0] = 0.333425;
				network.tDecay[0] = 1;
				network._inputEquil[0] = 0;
				network.weights[0] = [0.0700205, -0.400718];
				
				network.mDecay[1] = 1;
				network.tDecay[1] = 0;
				
				network.mDecay[2] = 0.692516;
				network.tDecay[2] = 0.0904454;
			}
		}
		spawnPickup(spawns[0]);
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

		if (settings.paceMaker && pacemaker)
			foreach(i; 0 .. pacemaker)
				network.inputs[$-1+i] += network.weights[$-1][i];

		float overlap = b2Distance(m_food.GetWorldCenter,m_body.GetWorldCenter);
		if (overlap < foodShape.m_radius+0.5) {
			++foodCount;
			energy += reward*(discount^^foodCount);
			if (foodCount > spawns.length - 2) foodCount = 0;
			m_food.SetTransform((spawns[foodCount].position),0);
		}
		import std.math : sqrt;

		float smellSense = 0;
		{
			auto ca =  m_body.GetAngle;
			auto cp = m_body.GetPosition;
			import core.stdc.math;
			float32 a = ca + (1.5)*(b2_pi);
			b2Vec2 p;
			p = cp + b2Vec2((settings.antLength) * cosf(a), (settings.antLength) * sinf(a));
			smellSense = b2Distance(m_food.GetPosition,p);

			if(settings.gradient)
			{
				import std.math : E, pow, sqrt;
				auto temp1 = pow(smellSense,2.5f);
				auto temp2 = pow((2 * (foodDistance/2)),2.5f) / 10;
				smellSense = pow(E,-(temp1/temp2));
				smellSense *= spawns[$-foodCount-1].alpha;
			}
			else
			{
				float dist = 1 - (smellSense / (foodDistance*1.1));
				
				if (dist < 0) {
					dist = 0;
				}
				if (dist > 1) {
					dist = 1;
				}
				smellSense = dist;
				smellSense *= spawns[$-foodCount-1].alpha;

			}
			
			import network.randNormal : randNormal;
			if(settings.noise > 0)
				smellSense = randNormal!float(smellSense,settings.noise,-1f,1f);
			

			if(settings.onNeuron) 
			{
				network.inputs[0] += smellSense;
				static if (m != m.cpu) {
					g_debugDraw.DrawSegment(cp,p,b2Color(1,1,1));
					if (network._spikes[0] > 0)
						g_debugDraw.DrawSolidCircle(p, 0.25f, b2Vec2(), b2Color(0f, 255f, 0f,255f));
				}
			}

			if(settings.offNeuron && smellNeurons > 1)
			{
				network.inputs[1] += 1 - smellSense;
				static if (m != m.cpu) {
					g_debugDraw.DrawSegment(cp,p,b2Color(1,1,1));
					if (network._spikes[1] > 0)
						g_debugDraw.DrawSolidCircle(p, 0.25f, b2Vec2(), b2Color(255f, 0f, 0f,255f));
				}
			}
		}

		network.tick(settings);
		energy -= 1;

		b2Vec2 p = m_body.GetPosition;
		
		if (network.outputs[0]) {
			b2Vec2 f = m_body.GetWorldVector(b2Vec2(-1.5f, -10f));
			m_body.ApplyLinearImpulse(f,p,true);
			energy -= 5;
		}
		if (network.outputs[1]) {
			b2Vec2 f = m_body.GetWorldVector(b2Vec2(1.5f, -10f));
			m_body.ApplyLinearImpulse(f,p,true);
			energy -= 5;
		}

		static if (m != m.cpu) {

			if (settings.chaseCam) {
				g_camera.m_center = m_body.GetWorldCenter;
			}

			foreach(i; 0 .. foodCount) {
				g_debugDraw.DrawSolidCircle(spawns[i].position, settings.foodRadius, b2Vec2(), b2Color(255f, 0f, 0f, 0.5f));
				auto textPos = spawns[i].position;
				textPos.x += 6;
				textPos.y -= 9;
				g_debugDraw.DrawString(textPos,to!string(i+1));
			}

			{
				float rangeToBody = b2Distance(m_food.GetWorldCenter,m_body.GetWorldCenter);
				b2Vec2 lastFoodPos = foodCount > 0 ? spawns[foodCount-1].position : b2Vec2();
				float nextFoodMaxDist = b2Distance(m_food.GetWorldCenter,lastFoodPos);
				float prox = (nextFoodMaxDist - rangeToBody) / nextFoodMaxDist;
				if (prox < 0) prox = 0;
					bestProx = prox;
			}

			trace ~= m_body.GetWorldCenter;

			b2Color heat = b2Color(0,1,0);

			if(settings.drawTrace)
			{
				foreach_reverse(i,t; trace) {
					g_debugDraw.DrawPoint(t, 2, heat);
					if (heat.g > 0) {
						heat.g -= 0.001;
						if (heat.r < 0.5) heat.r += 0.001;
					}
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
				foreach(s; network.outputs) {
					++creatureD.x;
					g_debugDraw.DrawPoint(creatureD, 10.0f,  b2Color(s,s,s)); //Input firing HUD
				}
			}

			if(settings.drawSensor)
			{
				foreach(i; 0 .. network.inputs.length) {
					b2Vec2 center;
					center.y = g_camera.m_center.y - 24;
					center.x = g_camera.m_center.x - network.inputs.length/2 + i;
					bool s = network._spikes[i];
					g_debugDraw.DrawPoint(center, 15f, b2Color(s,s,s)); //Input firing HUD

					if (i == network.inputs.length-1)
					{
						import std.conv : to;
						string str = to!string(smellSense);
						center.x += 1;
						g_debugDraw.DrawString(center, str);
					}
				}
			}
		}

		static if (m == m.cpu) {
			if (energy <= 0 || (sleepCounter > sleepAllowance)) {
				if(sleepCounter < sleepAllowance)
					network.fitness = calcFitness();
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

	float calcFitness()
	{
		float fitness = 0;
		float rangeToBody = b2Distance(m_food.GetWorldCenter,m_body.GetWorldCenter);
		b2Vec2 lastFoodPos = foodCount > 0 ? spawns[foodCount-1].position : b2Vec2();
		float nextFoodMaxDist = b2Distance(m_food.GetWorldCenter,lastFoodPos);
		float prox = (nextFoodMaxDist - rangeToBody) / nextFoodMaxDist;
		if (prox < 0) prox = 0;
		
		return prox + foodCount;
	}

	static NeuralTest Create()
	{
		return new typeof(this);
	}

	static Spawn[] createSpawns(Settings* set)
	{
		Spawn[] toReturn;
		float range = foodDistance;
		toReturn.length = 100;
		import std.math : PI;
		import core.stdc.math;
		float32 a = uniform(0,PI*2f);
		float temp = uniform(0,range);
		toReturn[0].position = b2Vec2(temp * cosf(a), temp * sinf(a));
		foreach(i,ref spawn; toReturn[1 .. $]) {
			if(i < 50)
			{
				a = uniform(0,PI*2f);
				temp = uniform(0,range);
				spawn.position = toReturn[i].position + b2Vec2(temp * cosf(a), temp * sinf(a));
//				spawn.x = toReturn[i].x + uniform(-range,range);
//				spawn.y = toReturn[i].y + uniform(-range,range);
			}
			else
			{
				import std.random : uniform01;
				spawn.alpha = uniform01;
			}
		}
		return toReturn;
	}

	static NetConf getNetConf()
	{
		size_t outputs = 2;
		return NetConf(pacemaker+smellNeurons,[],outputs);
	}
}

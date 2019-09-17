module tests.chemotaxistereo;

import dbox.common;
import deimos.glfw.glfw3;
import framework.debug_draw;
import framework.test;
import tests.test_entries : mode;
import network.network;
import std.conv : to;
import std.stdio;

class ChemotaxiB(mode m) : NeuralTest
{
	size_t foodCount;
	size_t boxDiminish;
	float32 creature_a;
	b2Vec2 creature_p;
	size_t sleepAllowance;
	size_t reward;
	b2Vec2[] localSpawns;
	enum smellNeurons = 2;
	enum pacemaker = 1;
	enum smellRange = 150;
	float dispMuscle;
	float distMuscle;


	this()
	{
		static if (m != m.cpu) {
			m_world.SetDebugDraw(g_debugDraw);
			if (!BGE.sampleReady) {
				network = new SNN(getNetConf);
				network.randomize;
				network.flush;
			}
			else network = BGE.getSample();
			spawns = createSpawns;
			settings = &main.settings;
			initialize;
		}
	}
	
	override void initialize()
	{
		if(settings.IF) network.tDecay[] = 0;

		if(settings.helperParams)
		{
			network.tDecay[0] = 1;
			network.mDecay[0] = 0;
			network._inputEquil[0] = 0;
		}

		if(settings.sensorClones)
		{
			network.tDecay[0..smellNeurons] = network.tDecay[0]; 
			network.mDecay[0..smellNeurons] = network.mDecay[0]; 
			network._inputEquil[0..smellNeurons] = network._inputEquil[0];
		}

		if(settings.motorClones)
		{
			network.mDecay[$-1] = network.mDecay[$-2];
			network.tDecay[$-1] = network.tDecay[$-2];
		}


		network.tDecay[getNetConf.inputs-1] = 0;
		boxDiminish = 400;
		reward = 4000;//2600;
		sleepAllowance = 10;
		energy = reward;
		
		//spawn first pickup from the spawns array
		spawnPickup(spawns[0]);

	}
	
	static if (m == m.user) {
		override void Keyboard(int key)
		{
			switch (key)
			{
				case GLFW_KEY_W:
				{
					b2Vec2 f = m_body.GetWorldVector(b2Vec2(0.0f, -10f));
					b2Vec2 p = m_body.GetWorldPoint(b2Vec2(0.0f, 0.0f));
					m_body.ApplyLinearImpulse(f,p,true);
					energy -= 10;
				}
					break;
					
				case GLFW_KEY_A:
				{
					m_body.ApplyAngularImpulse(0.35f,true);
				}
					break;
					
				case GLFW_KEY_D:
				{
					m_body.ApplyAngularImpulse(-0.35f,true);
				}
					break;

				case GLFW_KEY_S:
				{
					b2Vec2 f = m_body.GetWorldVector(b2Vec2(10.0f, 0f));
					b2Vec2 p = m_body.GetWorldPoint(b2Vec2(0.0f, 0.0f));
					m_body.ApplyLinearImpulse(f,p,true);
				}
					break;
					
				case GLFW_KEY_SPACE:
				{
					//eyes.process;
				}
					break;
					
				default:
					break;
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

		float overlap = b2Distance(m_food.GetWorldCenter,m_body.GetWorldCenter);
		if (overlap < foodShape.m_radius+0.5) {
			++foodCount;
			network.fitness += 1;
			energy += reward - (foodCount*boxDiminish);
			if (foodCount > spawns.length - 2) foodCount = 0;
			m_food.SetTransform((spawns[foodCount].position),0);
		}
		import std.math : sqrt;
		
		float rangeToNose = b2Distance(m_food.GetWorldCenter,m_body.GetPosition);
		b2Vec2 lastFoodPos = foodCount > 0 ? spawns[foodCount-1].position : b2Vec2();
		float nextFoodMaxDist = b2Distance(m_food.GetWorldCenter,lastFoodPos);
		float prox = (nextFoodMaxDist - rangeToNose) / nextFoodMaxDist;
		if (prox <= 0) {
			prox = 0;
		}
		if (prox > 1) {
			prox = 1;
		}
//		prox = prox^^2;
		//if (prox > bestProx)
		bestProx = prox;
		


		
		static if (m != m.user) {
			auto ca =  m_body.GetAngle;
			auto cp = m_body.GetPosition;
			float antDisp = 0.25f; //network.mDecay[$-1]/2;
			float antDist = network.tDecay[$-1];
			dispMuscle = 0.25f;
			distMuscle = 0.5f;
			dispMuscle += ((antDisp - dispMuscle) / 2);
			distMuscle += ((antDist - distMuscle) / 2) ;



			float angleA = 1f+dispMuscle;
			float angleB = 2f-dispMuscle;
			float angleC = 0f;
			auto angles = [angleA,angleB];
			
			foreach(i,ang; angles)
			{
				import core.stdc.math;
				float32 a = ca + (ang)*(b2_pi);
				b2Vec2 p;
				p = cp + b2Vec2((settings.antLength) * cosf(a), (settings.antLength) * sinf(a));
					
				float dist = b2Distance(m_food.GetWorldCenter,p);
				import std.math : sqrt;
				dist = 1 - (dist / smellRange);

				if (dist < 0) {
					dist = 0;
				}
				if (dist > 1) {
					dist = 1;
				}

				dist *= spawns[$-foodCount-1].position.x;

				import network.randNormal : randNormal;
				if(settings.noise > 0)
					dist = randNormal!float(dist,settings.noise,-1f,1f);

				network.inputs[i] += dist;

				static if (m != m.cpu) {
					g_debugDraw.DrawSegment(cp,p,b2Color(1,1,1));
					if (network._spikes[i] > 0)
						g_debugDraw.DrawSolidCircle(p, 0.25f, b2Vec2(), b2Color(0f, 255f, 0f,255f));
				}
			}

			if(settings.paceMaker && pacemaker)
				network.inputs[$-1] += 0.5f;

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

//			float finalAngularImpulse = 0;
//			if (network.outputs[0]) {
//				finalAngularImpulse += 0.5;
//			}
//			if (network.outputs[1]) {
//				finalAngularImpulse += 0.16;
//			}
//			if (network.outputs[1]) {
//				b2Vec2 f = m_body.GetWorldVector(b2Vec2(0.0f, -10f));
//				b2Vec2 p = m_body.GetWorldPoint(b2Vec2(0.0f, 3.0f));
//				m_body.ApplyLinearImpulse(f,p,true);
//				energy -= 10;
//			}
//			if (network.outputs[3]) {
//				finalAngularImpulse -= 0.16;
//			}
//			if (network.outputs[2]) {
//				finalAngularImpulse -= 0.5;
//			}
//			import std.math : abs;
//			float valuation = finalAngularImpulse.abs;
//			if(valuation > 0.5) energy -= 3;
//				else if (valuation > 0.16) energy -= 2;
//					else if (valuation > 0) energy -= 1;
//			m_body.ApplyAngularImpulse(finalAngularImpulse,true);
		}
		
		static if (m != m.cpu) {
		
			if (settings.chaseCam) {
				g_camera.m_center = m_body.GetWorldCenter;
			}
			if (settings.foodCam) {
				g_camera.m_center = m_food.GetWorldCenter;
			}

			foreach(i; 0 .. foodCount) {
				g_debugDraw.DrawSolidCircle(spawns[i].position, foodShape.m_radius, b2Vec2(), b2Color(255f, 0f, 0f, 0.5f));
				auto textPos = spawns[i].position;
				textPos.x += 1;
				textPos.y -= 1;
				g_debugDraw.DrawString(textPos,to!string(i+1));
			}

//			g_debugDraw.DrawCircle(spawns[foodCount], 150f,b2Color(0f, 255f, 0f, 0.2f));

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
		}

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

	import framework.test : Spawn;

	static Spawn[] createSpawns(Settings* set)
	{
		Spawn[] toReturn;
		float range = 100;
		toReturn.length = 100;
		toReturn[0].position = b2Vec2(uniform(-range,range),uniform(-range,range));
		foreach(i,ref spawn; toReturn[1 .. $]) {
			if(i < 50)
			{
				spawn.position.x = toReturn[i].position.x + uniform(-range,range);
				spawn.position.y = toReturn[i].position.y + uniform(-range,range);
			}
			else
			{
				import std.random : uniform01;
				spawn.position.x = uniform01;
			}
		}
		return toReturn;
	}

	static NetConf getNetConf()
	{
		return NetConf(pacemaker+smellNeurons,[2],2);
	}
}

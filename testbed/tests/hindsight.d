module tests.hindsight;

import dbox;
import deimos.glfw.glfw3;
import framework.debug_draw;
import framework.test;
import tests.test_entries : mode;
import network.network;
import std.conv : to;
import std.stdio;

class Hindsight(mode m) : NeuralTest
{
	size_t foodCount;
	size_t boxDiminish;
	float32 creature_a;
	b2Vec2 creature_p;
	size_t sleepAllowance;
	size_t reward;
	EyeCluster eyes;

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
			settings = &main.settings;
			spawns = createSpawns(settings);
			initialize;
		}
	}
	
	override class EyeCluster
	{
		float[] angles;
		float32 creature_angle;
		b2Vec2 creature_position;
		float32 eyeLength;
		size_t totalInputs;
		
		this(float length, float[] angles)
		{
			this.angles = angles;
			this.eyeLength = length;
		}
		
		void process()
		{
			creature_angle =  m_body.GetAngle;
			creature_position = m_body.GetPosition;

			foreach(i,angle; angles) {
				import core.stdc.math;
				float32 a = creature_angle + (angle)*(b2_pi);
				b2Vec2 p = creature_position + b2Vec2(eyeLength * cosf(a), eyeLength * sinf(a));
				
				m_world.RayCast(cb,creature_position,p);
							
				if (cb.m_hit) {
					network.inputs[i] += 0.5;
					cb.m_hit = false;

					static if (m != m.cpu) {
						g_debugDraw.DrawSegment(creature_position, cb.m_point, b2Color(1f, 0f, 0f));
					}
				}
				else {
					static if (m != m.cpu) {
						g_debugDraw.DrawSegment(creature_position, p, b2Color(0.8f, 0.8f, 0.8f));
					}
				}
			}
		}
	}

	override void initialize()
	{
		// Making all the sensory eye neurons identical: 
		if(settings.sensorClones)
		{
			network._inputEquil[0..backConeEyes.length] = network._inputEquil[0];
			network.tDecay[0..backConeEyes.length] = network.tDecay[0];
			network.mDecay[0..backConeEyes.length] = network.mDecay[0];
		}

		if(settings.IF) network.tDecay[] = 0;

		network.tDecay[$-1] = 0;
		boxDiminish = 50;	//diminshing returns multiplier for energy per food crate 
		reward = 1200;
		sleepAllowance = 5;
		energy = reward;
		
		eyes = new EyeCluster(40f, backConeEyes);
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
					b2Vec2 p = m_body.GetWorldPoint(b2Vec2(0.0f, 2.0f));
					m_body.ApplyLinearImpulse(f,p,true);
					energy -= 10;
				}
					break;
					
				case GLFW_KEY_A:
				{
					m_body.ApplyAngularImpulse(.5f,true);
					energy -= 2;
				}
					break;
					
				case GLFW_KEY_D:
				{
					m_body.ApplyAngularImpulse(-.5f,true);
					energy -= 2;
				}
					break;
					
				case GLFW_KEY_SPACE:
				{
					eyes.process;
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
	
		float CBdist = b2DistanceSquared(m_food.GetWorldCenter,m_body.GetWorldCenter);
		if (CBdist < foodShape.m_radius+0.5) {
			network.fitness += 1;
			energy = reward - (foodCount*boxDiminish);
			bestProx = 0;	
			++foodCount;
			if (foodCount > spawns.length - 2) foodCount = 0;
			m_food.SetTransform((spawns[foodCount].position),0);
		}


		CBdist = b2DistanceSquared(m_food.GetWorldCenter,m_body.GetPosition);
		
		b2Vec2 lastLocation = (foodCount == 0) ? b2Vec2(0,0) : spawns[foodCount-1].position;
		
		float nextFoodMaxDist = b2DistanceSquared(m_food.GetWorldCenter, lastLocation);
		float prox = ((nextFoodMaxDist-foodShape.m_radius+0.5) - CBdist) / nextFoodMaxDist;
		if (prox <= 0) {
			prox = 0;
		}
		if (prox > 1) {
			prox = 1;
		}
		prox = prox^^2;
		//if (prox > bestProx) 
		bestProx = prox;

		
		
		static if (m != m.user) {
//			if (firstTick) {
				if(settings.paceMaker) network.inputs[$-1] += 0.5f;
//				firstTick = false;
//			}
			eyes.process;
			network.tick(settings);
			energy -= 1;

			if (network.outputs[0]) {
				m_body.ApplyAngularImpulse(0.25f,true);
				energy -= 2;
//				network.inputs[$-2] += 0.5;
			}

			if (network.outputs[2]) {
				m_body.ApplyAngularImpulse(-0.25f,true);
				energy -= 2;
//				network.inputs[$-3] += 0.5;
			}

			if (network.outputs[1]) {
				b2Vec2 f = m_body.GetWorldVector(b2Vec2(0.0f, -5f));
				b2Vec2 p = m_body.GetWorldPoint(b2Vec2(0.0f, 2.0f));
				m_body.ApplyLinearImpulse(f,p,true);
//				network.inputs[$-4] += 0.5;
				energy -= 1;
			}
		}

		static if (m != m.cpu) {

			if (settings.chaseCam) {
				g_camera.m_center = m_body.GetWorldCenter;
			}
			if (settings.foodCam) {
				g_camera.m_center = m_food.GetWorldCenter;
			}

			foreach(i; 0 .. foodCount) {
				g_debugDraw.DrawPoint(spawns[i].position, 10.0f,  b2Color(255, 0, 0));
				auto textPos = spawns[i].position;
				textPos.x += 1;
				textPos.y -= 1;
				g_debugDraw.DrawString(textPos,to!string(i+1));
			}

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


		static if (m != m.user) {
			if (energy <= 0 || (sleepCounter > sleepAllowance)) {
				if (sleepCounter < sleepAllowance) {
					if (bestProx > 0) {
						network.fitness += bestProx;
					}
				}
				else network.fitness = 0;

				done = true;
			}
		}
	}
	
	static NeuralTest Create()
	{
		return new typeof(this);
	}

	static Spawn[] createSpawns(Settings* set)
	{
		Spawn[] toReturn;
		float range = 20;
		toReturn.length = 100;
		toReturn[0].position = b2Vec2(uniform(-range,range),uniform(-range,range));
		foreach(i,ref spawn; toReturn[1 .. $]) {
			spawn.position.x = toReturn[i].position.x + uniform(-range,range);
			spawn.position.y = toReturn[i].position.y + uniform(-range,range);
		}
		return toReturn;
	}

	static NetConf getNetConf()
	{
		return NetConf(backConeEyes.length + 1,[5],3);
	}
}

module tests.homerun;

import dbox.common;
import deimos.glfw.glfw3;
import framework.debug_draw;
import framework.test;
import tests.test_entries : mode;
import network.network;
import std.conv : to;
import std.stdio;

class Homerun(mode m) : NeuralTest
{
	size_t foodCount;
	size_t boxDiminish;
	float32 creature_a;
	b2Vec2 creature_p;
	size_t sleepAllowance;
	size_t reward;
	size_t eyeCounter;
	bool canSee;

	
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
	
	override void initialize()
	{
		network.tDecay[0 .. network.inputs.length] = 0;
		canSee = true;
		energy = 1700;// + cast(int)settings.hz*4;

		if(settings.IF) network.tDecay[] = 0;
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
		if (!m_body.IsAwake) {
			++sleepCounter;
		}
		else {
			sleepCounter = 0;
		}

		float CBdist = b2DistanceSquared(m_food.GetWorldCenter,m_body.GetWorldCenter);
		if (CBdist < foodShape.m_radius+0.5) {
			switch(foodCount)
			{
				case 0:
					energy = 1700;
					network.fitness += 1;
					m_food.SetTransform((spawns[1].position),0);
					++foodCount;
					canSee = false;
					break;
				case 1:
					network.fitness += 1f;
					++foodCount;
					break;
				default:
					break;
			}
		}

		CBdist = b2Distance(m_food.GetWorldCenter,m_body.GetPosition);
		float prox = 1 - (CBdist / 700);
		if (prox < 0 || prox > 1) {
			prox = 0;
		}
		//if (prox > bestProx) 
		bestProx = prox;

		static if (m != m.user) {
//			if (firstTick) {
				network.inputs[$-1] += 0.5f;
//				firstTick = false;
//			}
			network.tick(settings);
			energy -= 1;

			if(network.outputs[0]) {
				m_body.ApplyAngularImpulse(0.1f,true);
//				network.inputs[1] += 0.5f;
				//energy -= 1;
			}
			if(network.outputs[2]) {
				m_body.ApplyAngularImpulse(-0.1f,true);
//				network.inputs[2] += 0.5f;
				//energy -= 1;
			}

			if(network.outputs[1]) {
				b2Vec2 f = m_body.GetWorldVector(b2Vec2(0.0f, -5f));
				b2Vec2 p = m_body.GetWorldPoint(b2Vec2(0.0f, 2.0f));
				m_body.ApplyLinearImpulse(f,p,true);
//				network.inputs[3] += 0.5f;
				energy -= 10;
			}
			if (!canSee)
				network.inputs[$-2] += 0.5f;
		}
		
		static if (m != m.cpu) {
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

			if (settings.chaseCam) {
				g_camera.m_center = m_body.GetWorldCenter;
			}
			if (settings.foodCam) {
				g_camera.m_center = m_food.GetWorldCenter;
			}

			if (settings.drawOutputs) {
				creatureD.y -= 1;
				creatureD.x -= (network.outputs.length/2f) - 0.5f;
				foreach(outputValue; network.outputs) {
					++creatureD.x;
					g_debugDraw.DrawPoint(creatureD, 10.0f,  b2Color(outputValue, outputValue, outputValue)); //Input firing HUD
				}
			}

			if (!canSee) {
				auto pos = m_body.GetWorldCenter;
				pos.y += 2;
				pos.x -= 1.9f;
				g_debugDraw.DrawString(pos, "*BLIND*");
			}
		}

		static if (m != m.user) {
			if (canSee) {
				auto ca =  m_body.GetAngle;
				auto cp = m_body.GetPosition;
				auto ang = 1.5f;

				import core.stdc.math;
			

				float32 _a = ca + (ang)*(b2_pi);
				b2Vec2 _p = cp + b2Vec2(40f * cosf(_a), 40f * sinf(_a));
				
				m_world.RayCast(cb,cp,_p);
				
				if (cb.m_hit) {
					network.inputs[0] += 0.5f;
					cb.m_hit = false;
					static if (m != m.cpu) {
						g_debugDraw.DrawSegment(cp, cb.m_point, b2Color(1f, 0f, 0f));
					}
				}
				else {
					static if (m != m.cpu) {
						g_debugDraw.DrawSegment(cp, _p, b2Color(0.8f, 0.8f, 0.8f));
					}
				}
			}

			if (energy <= 0) {
				if (foodCount == 2) network.fitness = 3;
				else network.fitness += bestProx;

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
		toReturn.length = 2;
	
		foreach(i; 0 .. toReturn.length-1) {
			float minRange = 3;
			float maxRange = 25;
			float xa;
			if(uniform(0,2)) xa = uniform(minRange,maxRange);
			else xa = -uniform(minRange,maxRange);

			float ya;
			if(uniform(0,2)) ya = uniform(minRange,maxRange);
			else ya = -uniform(minRange,maxRange);

			toReturn[i].position.x = xa;
			toReturn[i].position.y = ya;
		}
		return toReturn;
	}

	static NetConf getNetConf()
	{
		return NetConf(3,[10],3);
	}
}

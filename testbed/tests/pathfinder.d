module tests.pathfinder;

import dbox.common;
import deimos.glfw.glfw3;
import framework.debug_draw;
import framework.test;
import tests.test_entries : mode;
import network.network;
import std.conv : to;
import std.stdio;


class Pathfinder(mode m) : NeuralTest
{
	size_t foodCount;
	float32 creature_a;
	b2Vec2 creature_p;
	size_t sleepAllowance;
	size_t reward;


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
		//settings.foodRadius = 1.5;
		network.tDecay[0] = 0;
		spawns = createLocalSpawns;
		reward = 6;
		energy = reward;
		energy += 25;

		if(settings.IF) network.tDecay[] = 0;
		//spawn first pickup from the spawns array
		spawnPickup(spawns[0]);
		m_body.SetTransform(b2Vec2(0,0),2);

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
					//energy -= 10;
				}
					break;
					
				case GLFW_KEY_A:
				{
					m_body.ApplyAngularImpulse(.5f,true);
					//energy -= 2;
				}
					break;
					
				case GLFW_KEY_D:
				{
					m_body.ApplyAngularImpulse(-.5f,true);
					//energy -= 2;
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
		static if ( m != m.user) {
			if (!m_body.IsAwake)
				++sleepCounter;
			else
				sleepCounter = 0;
		}

		b2Vec2 lastLocation;

		float CBdist = b2Distance(m_food.GetWorldCenter,m_body.GetPosition);
		if (CBdist < foodShape.m_radius+0.5) {
			network.fitness += 1;
			energy = reward;
			bestProx = 0;
			++foodCount;
			if (foodCount > spawns.length - 2) foodCount = 0;
			m_food.SetTransform((spawns[foodCount].position),0);
			lastLocation = m_body.GetPosition;
		}

		float nextFoodMaxDist = b2Distance(m_food.GetWorldCenter, lastLocation);
		float prox = (nextFoodMaxDist - CBdist) / nextFoodMaxDist;
		if (prox <= 0) {
			prox = 0;
		}
		if (prox > 1) {
			prox = 1;
		}
		bestProx = prox;
		
		
		
		static if (m != m.user) {
	
			network.inputs[0] += 0.5f;
			//network.inputs[3 .. 6] -= 0.5f;
			network.tick(settings);
	
			energy -= 1;

//			if (network.outputs[0]) {
//				b2Vec2 f = m_body.GetWorldVector(b2Vec2(0.5f, -10f));
//				b2Vec2 p = m_body.GetWorldPoint(b2Vec2(0.0f, 3.0f));
//				m_body.ApplyLinearImpulse(f,p,true);
//			}
//			if (network.outputs[1]) {
//				b2Vec2 f = m_body.GetWorldVector(b2Vec2(-0.5f, -10f));
//				b2Vec2 p = m_body.GetWorldPoint(b2Vec2(0.0f, 3.0f));
//				m_body.ApplyLinearImpulse(f,p,true);
//			}
			if (network.outputs[0]) {
				m_body.ApplyAngularImpulse(0.5f, true);
			}
			if (network.outputs[2]) {
				m_body.ApplyAngularImpulse(-0.5f, true);
			}
			if (network.outputs[1]) {
				b2Vec2 f = m_body.GetWorldVector(b2Vec2(0.0f, -10f));
				b2Vec2 p = m_body.GetWorldPoint(b2Vec2(0.0f, 2.0f));
				m_body.ApplyLinearImpulse(f,p,true);
			}


//			if (network.outputs[0])
//				network.inputs[1] += 0.5f;
//			if (network.outputs[1])
//				network.inputs[2] += 0.5f;
//			if (network.outputs[2])
//				network.inputs[3] += 0.5f;

		}

		static if (m != m.cpu) {

			foreach(i,spawn; spawns) {
				if (i == cast(int)BGE.bestFitness)
					g_debugDraw.DrawCircle(spawn.position, foodShape.m_radius, b2Color(0f, 255f, 0f,180));
				else 
					g_debugDraw.DrawCircle(spawn.position, foodShape.m_radius, b2Color(0f, 0f, 0f,180f));

//				if (i > 0)
//					g_debugDraw.DrawSegment(spawn,spawns[i-1],b2Color(0f, 0f, 0f));
			}
			if (settings.chaseCam) {
				g_camera.m_center = m_body.GetWorldCenter;
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
//			g_debugDraw.DrawString(creatureD, to!string(energy));

			if (settings.drawOutputs) {
				creatureD.y -= 1;
				creatureD.x -= (network.outputs.length/2f) - 0.5f;
				foreach(outputValue; network.outputs) {
					++creatureD.x;
					g_debugDraw.DrawPoint(creatureD, 10.0f,  b2Color(outputValue, outputValue, outputValue)); //Input firing HUD
				}
			}

			// Output spikes visuals
		}

		if (foodCount > 320)
			assert(0);

		static if (m != m.user) {
			if (energy <= 0) {
				if (bestProx > 0)
					network.fitness += bestProx;
//				else
//					network.fitness -= 2;
				done = true;
			}
		}
	}

	static NeuralTest Create()
	{
		return new typeof(this);
	}

	Spawn[] createLocalSpawns()
	{
		Spawn[] toReturn;
		toReturn.length = 320;
		int y = 0;
		int x = 2;

		//#TODO make a case switch. This is horrible.
		foreach(i,ref spawn; toReturn) {
			if (i < 20) {
				++x;
			}
			else {
				if (i < 40) {
					if (i == 20) ++x;
					++y;
				}
				else {
					if (i < 80) {
						if (i == 40) ++y;
						--x;
					}
					else {
						if (i < 120) {
							if (i == 80) --x;
							--y;
						}
						else {
							if (i < 160) {
							--x;
							--y;
							}
							else {
								if (i < 180) {
								--x;
								}
								else {
									if (i < 238) {
										if (i == 180) --x;
										++y;
									}
									else {
										if (i == 238) ++y;
										++x;
									}
								}
							}
						}
					}	
				}
			}
			spawn.position = b2Vec2(x,y);
		}
		return toReturn;
	}

	static NetConf getNetConf()
	{
		return NetConf(1,[100],3);
	}
}

module tests.junction;

import dbox.common;
import deimos.glfw.glfw3;
import framework.debug_draw;
import framework.test;
import tests.test_entries : mode;
import network.network;
import std.conv : to;
import std.stdio;

class Junction(mode m) : NeuralTest
{
	bool signal;
	size_t signalIdx;
	size_t foodCount;
	float32 creature_a;
	b2Vec2 creature_p;
	size_t sleepAllowance;
	size_t reward;
	size_t track;
	float tempFitness;

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
		network.mDecay[0] = 0.5f;
		network.tDecay[0] = 0.4f;
		network.tDecay[1] = 0;
		if(settings.IF) network.tDecay[] = 0;
		network._inputEquil[0] = 0.5f;
		sleepCounter = 0;
		foodCount = 0;
		m_body.m_angularVelocity = 0;
		m_body.m_linearVelocity = b2Vec2(0,0);
		m_body.SetTransform(b2Vec2(0,0),-1);
		spawns = createLocalSpawns(track);
		sleepAllowance = 5;
		spawnPickup(spawns[0]);
		reward = 6;
		energy = 20 + reward;
		bestProx = 0;
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
					m_body.ApplyAngularImpulse(1f,true);
					energy -= 2;
				}
					break;
					
				case GLFW_KEY_D:
				{
					m_body.ApplyAngularImpulse(-1f,true);
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

		b2Vec2 lastLocation;

		float CBdist = b2Distance(m_food.GetWorldCenter,m_body.GetPosition);
		if (CBdist < foodShape.m_radius+0.5) {
			network.fitness += 1;
			energy = reward;
			++foodCount;
			if (foodCount > spawns.length - 2) foodCount = 0;
			m_food.SetTransform((spawns[foodCount].position),0);
			CBdist = b2DistanceSquared(m_food.GetWorldCenter,m_body.GetPosition);
			bestProx = 0;
			lastLocation = m_body.GetPosition;
		}
		
		float nextFoodMaxDist = b2Distance(m_food.GetWorldCenter, lastLocation);
		float prox =  (nextFoodMaxDist - CBdist) / nextFoodMaxDist;
		if (prox <= 0) {
			prox = 0;
		}
		if (prox > 1) {
			prox = 1;
		}
		bestProx = prox;


		static if (m != m.user) {

			network.inputs[0] += -1f;
			network.inputs[1] += 0.5f;


			network.tick(settings);
			energy -= 1;


//			if (network.outputs[0]) {
//				b2Vec2 f = m_body.GetWorldVector(b2Vec2(0.5f, -10f));
//				b2Vec2 p = m_body.GetWorldPoint(b2Vec2(0.0f, 3.0f));
//				m_body.ApplyLinearImpulse(f,p,true);
////				energy -= 5;
//			}
//			if (network.outputs[1]) {
//				b2Vec2 f = m_body.GetWorldVector(b2Vec2(-0.5f, -10f));
//				b2Vec2 p = m_body.GetWorldPoint(b2Vec2(0.0f, 3.0f));
//				m_body.ApplyLinearImpulse(f,p,true);
////				energy -= 5;
//			}
			if (network.outputs[0]) {
				m_body.ApplyAngularImpulse(0.5f,true);
//				network.inputs[2] += 0.5f;
			}
			if (network.outputs[2]) {
				m_body.ApplyAngularImpulse(-0.5f,true);
//				network.inputs[3] += 0.5f;

			}
			if (network.outputs[1]) {
				b2Vec2 f = m_body.GetWorldVector(b2Vec2(0.0f, -10f));
				b2Vec2 p = m_body.GetWorldPoint(b2Vec2(0.0f, 2.0f));
				m_body.ApplyLinearImpulse(f,p,true);
//				network.inputs[4] += 0.5f;
			}
		}

		signalIdx = settings.signalIdx;

		if (track == 1 && foodCount == signalIdx && !signal) {
			network.inputs[0] += 1;
			signal = true;
		}

		static if (m != m.cpu) {
			foreach(i,spawn; spawns) {
				if (i > 0)
					g_debugDraw.DrawSegment(spawn.position,spawns[i-1].position,b2Color(0f, 0f, 0f));
				if (i == signalIdx) {
					if (track == 1) {
						g_debugDraw.DrawCircle(spawn.position, foodShape.m_radius, b2Color(0f, 1f, 1f,180f));
					}
					else g_debugDraw.DrawCircle(spawn.position, foodShape.m_radius, b2Color(0f, 0f, 0f,180f));
					spawn.position.x += 1;
					g_debugDraw.DrawString(spawn.position,"Signal Spike");
				}
				else
					g_debugDraw.DrawCircle(spawn.position, foodShape.m_radius, b2Color(0f, 0f, 0f,180f));
		

				if (i == cast(int)BGE.bestFitness) {
					g_debugDraw.DrawCircle(spawn.position, foodShape.m_radius, b2Color(0f, 1f, 0f,180f));
				}
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

			if (settings.chaseCam) {
				g_camera.m_center = m_body.GetWorldCenter;
			}
			if (settings.foodCam) {
				g_camera.m_center = m_food.GetWorldCenter;
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
					g_debugDraw.DrawPoint(creatureD, 10.0f, b2Color(outputValue, outputValue, outputValue)); //Input firing HUD
				}
			}
		}

		static if (m != m.user) {
			if (energy <= 0 || (sleepCounter > sleepAllowance)) {
				if (bestProx > 0)
					network.fitness += bestProx;
				else
					network.fitness -= 1;
				++track;
				if (track > 1) {
					if (network.fitness > tempFitness)
						network.fitness = tempFitness;
					done = true;
				}
				else {
					tempFitness = network.fitness;
					m_world.DestroyBody(m_food);
					network.flush;
					trace.length = 0;
					initialize;
				}
			}
		}
	}
	
	static NeuralTest Create()
	{
		return new typeof(this);
	}

	// #TODO make a case switch
	Spawn[] createLocalSpawns(size_t var)
	{
		assert(var == 0 || var == 1);
		Spawn[] toReturn;
		
		if (var == 0) {
			toReturn.length = 180;
			int y = 0;
			int x = -2;
			
			foreach(i,ref spawn; toReturn) {
				if (i < 20) {
					--x;
				}
				else {
					if (i < 40) {
						if(i == 20) --x;
						++y;
					}
					else {
						if (i < 50) {
							if(i == 40) ++y;
							--x;
						}
						else {
							if (i < 60) {
								if(i == 50) --x;
								--y;
							}
							else {
								if(i < 100) {
									if	(i == 60) --y;
									--x;
								}
								else {
									if (i < 120) {
										if	(i == 100) --x;
										--y;
									}
									else {
										if	(i == 120) --y;
										++x;
									}
								}
							}
						}	
					}
				}
				toReturn[i].position = b2Vec2(x,y);
			}
		}
		if (var == 1) {
			toReturn.length = 180;
			int y = 0;
			int x = -2;

			foreach(i,ref spawn; toReturn) {
				if (i < 20) {
					--x;
				}
				else {
					if (i < 40) {
						if(i == 20) --x;
						++y;
					}
					else {
						if (i < 70) {
							if(i == 40) ++y;
							++x;
						}
						else {
							if (i < 120) {
								if(i == 70) ++x;
								--y;
							}
							else {
								if(i == 120) --y;
								--x;
							}
						}	
					}
				}
				toReturn[i] = Spawn(b2Vec2(x,y));
			}
		}
		assert(toReturn !is null);
		return toReturn;
	}

	static NetConf getNetConf()
	{
		return NetConf(2,[100],3);
	}
}

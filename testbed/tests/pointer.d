module tests.pointer;

import dbox;
import deimos.glfw.glfw3;
import framework.debug_draw;
import framework.test;
import tests.test_entries : mode;
import network.network;
import std.conv : to;
import std.stdio;

class Pointer(mode m) : NeuralTest
{
	size_t foodCount;
	size_t boxDiminish;
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
		reward = 200;
		energy = reward;
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
					b2Vec2 f = m_body.GetWorldVector(b2Vec2(0.0f, -0.5f));
					b2Vec2 p = m_body.GetWorldPoint(b2Vec2(0.0f, 2.0f));
					m_body.ApplyLinearImpulse(f,p,true);
					energy -= 10;
				}
					break;
					
				case GLFW_KEY_A:
				{
					m_body.ApplyAngularImpulse(.05f,true);
					energy -= 2;
				}
					break;
					
				case GLFW_KEY_D:
				{
					m_body.ApplyAngularImpulse(-.05f,true);
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

			network.inputs[0] += 0.5f;
			network.tick(settings);
			energy -= 1;

			if (network.outputs[0])
			{
				m_body.ApplyAngularImpulse(0.5f,true);
//				network.inputs[2] += 0.5f;
//				energy -= 2;
			}

			if (network.outputs[1])
			{
				m_body.ApplyAngularImpulse(0.15f,true);
//				network.inputs[3] += 0.5f;
//				energy -= 1;
			}
			if (network.outputs[2])
			{
				m_body.ApplyAngularImpulse(-0.15f,true);
//				network.inputs[4] += 0.5f;
//				energy -= 1;
			}
			if (network.outputs[3])
			{
				m_body.ApplyAngularImpulse(-0.5f,true);
//				network.inputs[5] += 0.5f;
//				energy -= 2;
			}
		}
		
		static if (m != m.cpu) {
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

		static if (m != m.user) {
			auto ca =  m_body.GetAngle;
			auto cp = m_body.GetPosition;
			auto ang = 1.5f;

			import core.stdc.math;

			float32 _a = ca + (ang)*(b2_pi);
			b2Vec2 _p = cp + b2Vec2(40f * cosf(_a), 40f * sinf(_a));
			
			m_world.RayCast(cb,cp,_p);
			
			if (cb.m_hit) {
				network.inputs[1] += 0.5f;
				network.fitness += 1;
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

			static if(m == m.cpu)
			{
				if (energy <= 0)
					done = true;
			}
			else
			{
				if(!settings.infEnergy)
					if (energy <= 0)
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
		toReturn.length = 1;

		float xa;
		if(uniform(0,2)) xa = uniform(4,8);
		else xa = -uniform(4,8);
		
		float ya;
		if(uniform(0,2)) ya = uniform(4,8);
		else ya = -uniform(4,8);
		
		toReturn[0].position.x = xa;
		toReturn[0].position.y = ya;

		return toReturn;
	}

	static NetConf getNetConf()
	{
		return NetConf(2,[2],4);
	}
}

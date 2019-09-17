module tests.spotter;

import dbox;
import deimos.glfw.glfw3;
import framework.debug_draw;
import framework.test;
import tests.test_entries : mode;
import network.network;
import std.conv : to;
import std.stdio;

class Spotter(mode m) : NeuralTest
{
	b2Body* ground;
	size_t foodCount;
	size_t boxDiminish;
	float32 creature_a;
	b2Vec2 creature_p;
	size_t sleepAllowance;
	size_t reward;
	size_t eyeCounter;
	EyeClusterProx eyes;
	
	class EyeClusterProx
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
			//			size_t index;
			
			foreach(i,angle; angles) {
				import core.stdc.math;
				float32 a = creature_angle + (angle)*(b2_pi);
				b2Vec2 p = creature_position + b2Vec2(eyeLength * cosf(a), eyeLength * sinf(a));
				
				m_world.RayCast(cb,creature_position,p);
				float proximity = 0;
				
				size_t leftWallEye = angles.length-1;
				size_t rightWallEye = 0;
				size_t centerWallEye = angles.length/2;
				
				bool isWallEye = (i == leftWallEye || i == rightWallEye || i == centerWallEye);
				
				if (cb.m_body is m_food) {
					proximity = 1;
					switch(i)
					{
						case 2:
							network.fitness += 0.05f;
							break;
						case 1:
							network.fitness += 0.025f;
							break;
						case 3:
							network.fitness += 0.025f;
							break;
						case 0:
							network.fitness += 0.01f;
							break;
						case 4:
							network.fitness += 0.01f;
							break;
						default:
							break;
					}
					network.inputs[i] +=  0.5f;//proximity;
				}
				
				static if (m != m.cpu) {
					//Input firing HUD
					g_debugDraw.DrawSegment(creature_position, cb.m_point, b2Color(proximity, proximity, proximity));
					float tempy = i;
					b2Vec2 position = b2Vec2(-tempy+3f,32);
					g_debugDraw.DrawPoint(position, 15f, b2Color(proximity, proximity, proximity)); 
					
					if (m == m.user) {
						//						writeln(proximity);
						writeln("----");
						foreach(membrane; network.inputs[angles.length .. angles.length + 3])
							writeln(membrane);
						
						network.inputs[angles.length .. angles.length + 3] = 0;
					}
				}
			}
		}
	}
	
	
	this()
	{
		super(true); // Making the creature a sensor (no collision)
		static if (m != m.cpu) {
			m_world.SetDebugDraw(g_debugDraw);
			network = BGE.getSample();
			settings = &main.settings;
			spawns = createSpawns(settings);
			initialize;
		}
	}
	
	void applyRandomForce()
	{
		import std.random;
		b2Vec2 f = m_food.GetWorldVector(spawns[0].position);
		b2Vec2 p = m_food.GetWorldCenter();
		m_food.ApplyLinearImpulse(f,p,true);
	}
	
	
	override void initialize()
	{
		if(settings.bestNetwork)
		{
			// L1:
			
			// -------------------------------
			network._inputEquil[0] = 0;
			network.mDecay[0] = 0.906287;
			network.tDecay[0] = 0.758276;
			network.weights[0] = [-0.893198, 0.646661];
			
			// -------------------------------
			network._inputEquil[1] = 0;
			network.mDecay[1] = 0.906287;
			network.tDecay[1] = 0.758276;
			network.weights[1] = [-0.613507, -0.0312183];
			
			// -------------------------------
			network._inputEquil[2] = 0;
			network.mDecay[2] = 0.906287;
			network.tDecay[2] = 0.758276;
			network.weights[2] = [0.750778, 0.939271];
			
			// -------------------------------
			network._inputEquil[3] = 0;
			network.mDecay[3] = 0;
			network.tDecay[3] = 1;
			network.weights[3] = [0, 0.654737];
			
			
			// L2:
			
			// -------------------------------
			network.mDecay[4] = 0.0411669;
			network.tDecay[4] = 0;
			network.weights[4] = [0.827061, -0.088673];
			
			// -------------------------------
			network.mDecay[5] = 0.544789;
			network.tDecay[5] = 0;
			network.weights[5] = [0.193314, 0.749405];
			
			
			// L3:
			
			// -------------------------------
			network.mDecay[6] = 0.077598;
			network.tDecay[6] = 0;
			network.weights[6] = [0.583305, -0.594087];
			
			// -------------------------------
			network.mDecay[7] = 0.679271;
			network.tDecay[7] = 1;
			network.weights[7] = [-0.0144544, 0.535442];
		}

		if(settings.sensorClones)
		{
			foreach(i; 0 .. frontConeEyes(true).length) 
			{
				network._inputEquil[i] = network._inputEquil[0];
				network.mDecay[i] = network.mDecay[0];
				network.tDecay[i] = network.tDecay[0];
			}
		}

		if(settings.motorClones)
		{
			network.mDecay[$-1] = network.mDecay[$-2];
			network.tDecay[$-1] = network.tDecay[$-2];
		}

		if(settings.IF) network.tDecay[] = 0;
		
		reward = 1000;
		sleepAllowance = 10;
		energy = reward;
		foodCount = 0;
		
		eyes = new EyeClusterProx(60f, frontConeEyes(settings.triRay));
		//spawn first pickup from the spawns array
		
		spawnPickup(spawns[1]);
		
		auto shape = new b2EdgeShape();
		b2FixtureDef sd;
		sd.shape       = shape;
		sd.density     = 0.0f;
		//sd.restitution = k_restitution;
		
		{
			b2BodyDef bd;
			bd.position.Set(0.0f, 0.0f);
			ground = m_world.CreateBody(&bd);
			
			// Left vertical
			shape.Set(b2Vec2(-30.0f, -30.0f), b2Vec2(-30.0f, 30.0f));
			ground.CreateFixture(&sd);
			
			// Right vertical
			shape.Set(b2Vec2(30.0f, -30.0f), b2Vec2(30.0f, 30.0f));
			ground.CreateFixture(&sd);
			
			//Top horizontal
			shape.Set(b2Vec2(-30.0f, 30.0f), b2Vec2(30.0f, 30.0f));
			ground.CreateFixture(&sd);
			
			// Bottom horizontal
			shape.Set(b2Vec2(-30.0f, -30.0f), b2Vec2(30.0f, -30.0f));
			ground.CreateFixture(&sd);
		} 

		settings.foodRadius = 0.5f;
		settings.recurrent = true;
		applyRandomForce;
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
					//					energy -= 10;
				}
					break;
					
				case GLFW_KEY_A:
				{
					m_body.ApplyAngularImpulse(.5f,true);
					//					energy -= 2;
				}
					break;
					
				case GLFW_KEY_D:
				{
					m_body.ApplyAngularImpulse(-.5f,true);
					//					energy -= 2;
				}
					break;
					
				case GLFW_KEY_F:
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
		
		static if (m != m.user) {
			
			eyes.process;
			network.tick(settings);
			energy -= 1;

			if(settings.paceMaker)
				network.inputs[$-1] += 0.5f;

			float leftMovement = network.outputs[0];
			float rightMovement = network.outputs[1];
			
			if (network.outputs[0] != network.outputs[1])
			{
				if (leftMovement > 0) {
					m_body.ApplyAngularImpulse(0.05f,true);
				}
				if (rightMovement > 0) {
					m_body.ApplyAngularImpulse(-0.05f,true);
				}
			}
		}

		static if (m != m.cpu) {
		
			
			if (settings.chaseCam) {
				g_camera.m_center = m_body.GetWorldCenter;
			}
			
			if (settings.foodCam) {
				g_camera.m_center = m_food.GetWorldCenter;
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
					g_debugDraw.DrawPoint(creatureD, 10.0f, b2Color(outputValue, outputValue, outputValue)); //Input firing HUD
				}
			}
		}
		
		static if (m == m.cpu) {
			if (energy <= 0 || sleepCounter > sleepAllowance) {
				done = true;
			}
		}

		static if(m == m.render) {
			if(!settings.infEnergy)
				if (energy <= 0)
					done = true;
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
		
		float range = 15;
		foreach(i,ref spawn; toReturn) 
		{
			spawn.isStatic = false;
			if(i == 0)
			{
				if (uniform(0,2))
				{
					spawn.position.x = 10;//uniform(-range,range);
					spawn.position.y = 0;
				}
				else
				{
					spawn.position.x = 0;
					spawn.position.y = 10; //uniform(-range,range);
				}
			}
			else
			{
				while(spawn.position.x < 3 && spawn.position.x > -3)
					spawn.position.x = uniform(-range,range);
				
				while(spawn.position.y < 3 && spawn.position.y > -3)
					spawn.position.y = uniform(-range,range);
			}
		}
		return toReturn;
	}
	static NetConf getNetConf()
	{
		return NetConf(frontConeEyes(main.settings.triRay).length + 1,[2],2);
	}
}

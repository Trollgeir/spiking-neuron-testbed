module tests.catcher;

import dbox;
import deimos.glfw.glfw3;
import framework.debug_draw;
import framework.test;
import tests.test_entries : mode;
import network.network;
import std.conv : to;
import std.stdio;

class Catcher(mode m) : NeuralTest
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
				float proximity = 0;

				size_t leftWallEye = angles.length-1;
				size_t rightWallEye = 0;
				size_t centerWallEye = angles.length/2;

				bool isWallEye = (i == leftWallEye || i == rightWallEye || i == centerWallEye);

				if (cb.m_body is m_food) {
//					auto dist = b2DistanceSquared(cb.m_point,creature_position);
//					proximity = 1 - (dist / 1500);
//					if (proximity > 1) proximity = 1;
//					if (proximity < 0) proximity = 0;
//					proximity = proximity^^2;
//					cb.m_hit = false;
					proximity = 1;
					network.inputs[i] +=  0.5f;//proximity;
				}
				else if (cb.m_body is ground && isWallEye) {
					auto dist = b2DistanceSquared(cb.m_point,creature_position);
					float proxi = 1 - (dist / 1500);
					if (proxi > 1) proximity = 1;
					if (proxi < 0) proximity = 0;
					proxi= proxi^^2;
					size_t index;
					if (i == leftWallEye) index = 0;
					if (i == centerWallEye) index = 1;
					if (i == rightWallEye) index = 2;
					network.inputs[angles.length+index] += proxi;
				}



//				index += 1;

				static if (m != m.cpu) {
					//Input firing HUD
					g_debugDraw.DrawSegment(creature_position, cb.m_point, b2Color(proximity, proximity, proximity));
					float tempy = i;
					b2Vec2 position = b2Vec2(-tempy+3f,32);
					g_debugDraw.DrawPoint(position, 15f, b2Color(proximity, proximity, proximity)); 

					if (m == m.user) {
						writeln(proximity);
					}
				}
			}
		}
	}

	
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

	void applyRandomForce()
	{
		import std.random;
		b2Vec2 f = m_food.GetWorldVector(spawns[$-foodCount]);
		b2Vec2 p = m_food.GetWorldCenter();
		m_food.ApplyLinearImpulse(f,p,true);
	}


	override void initialize()
	{
		// Making all the sensory eye neurons identical: 
		size_t index;

		foreach(i; 0 .. frontConeEyes.length) {
			network._inputEquil[index] = network._inputEquil[0];
			network.mDecay[index] = network.mDecay[0];
			network.tDecay[index] = network.tDecay[0];
			index += 1;
		}

//		network._inputEquil[0 ..frontConeEyes.length*3] = 1f;
//		network.tDecay[0..frontConeEyes.length*1] = network.tDecay[0];
//		network.mDecay[0..frontConeEyes.length*1] = network.mDecay[0];

		if(settings.IF) network.tDecay[] = 0;

		boxDiminish = 50;	//diminshing returns multiplier for energy per food crate 
		reward = 500;
		sleepAllowance = 15;
		energy = reward;
		// Using the first spawnlocation for the creature
		foodCount = 1;
		
		eyes = new EyeClusterProx(60f, frontConeEyes);
		//spawn first pickup from the spawns array
		
		spawnPickup(spawns[1],false);
		
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
		m_body.SetTransform(spawns[0],0);
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
		if (CBdist < foodShape.m_radius+3) {
			network.fitness += 1;
			energy += reward - (foodCount*boxDiminish);
			bestProx = 0;	
			++foodCount;
			if (foodCount > spawns.length - 2) foodCount = 0;
			m_food.SetTransform((spawns[foodCount]),0);
			applyRandomForce();
		}
		

		CBdist = b2DistanceSquared(m_food.GetWorldCenter,m_body.GetPosition);
		
//		b2Vec2 lastLocation = spawns[foodCount-1];
		
//		float nextFoodMaxDist = b2DistanceSquared(m_food.GetWorldCenter, lastLocation);
//		float prox = ((nextFoodMaxDist-foodShape.m_radius+0.5) - CBdist) / nextFoodMaxDist;

		float prox = 1 - (CBdist / 600);
		prox = prox^^2;

		if (prox <= 0 || prox > 1) {
			prox = 0;
		}
		prox = prox^^2;
		//if (prox > bestProx) 
		bestProx = prox;
		
		
		
		static if (m != m.user) {

			eyes.process;
			network.tick(settings);
			//energy -= 1;

			network.inputs[$-1] += 0.5f;
			//network.inputs[35] -= 1f;

			float leftMovement = network.outputs[0];
			float rightMovement = network.outputs[2];
			float forwardMovement = network.outputs[1];
			float strafeLeft = network.outputs[3];
			float strafeRight = network.outputs[4];

			energy -= 1;	

			if (network.outputs[0] != network.outputs[2])
			{
				if (leftMovement > 0) {
					m_body.ApplyAngularImpulse(0.25f,true);
					network.inputs[$-2] += 0.5f;
//					energy -= 1f;
				}
				if (rightMovement > 0) {
					m_body.ApplyAngularImpulse(-0.25f,true);
					network.inputs[$-3] += 0.5f;
//					energy -= 1f;
				}
			}

//			if (network.outputs[3] != network.outputs[4])
//			{
//				if (strafeLeft > 0) {
//					b2Vec2 f = m_body.GetWorldVector(b2Vec2(-3, 0f));
//					b2Vec2 p = m_body.GetWorldCenter();
//					m_body.ApplyLinearImpulse(f,p,true);
//					network.inputs[$-4] += 0.5f;
//				}
//				if (strafeRight > 0) {
//					b2Vec2 f = m_body.GetWorldVector(b2Vec2(3, 0f));
//					b2Vec2 p = m_body.GetWorldCenter();
//					m_body.ApplyLinearImpulse(f,p,true);
//					network.inputs[$-5] += 0.5f;
//				}
//			}

			if (forwardMovement > 0) {
				b2Vec2 f = m_body.GetWorldVector(b2Vec2(0.0f, -5f));
				b2Vec2 p = m_body.GetWorldPoint(b2Vec2(0.0f, 2.0f));
				m_body.ApplyLinearImpulse(f,p,true);
				network.inputs[$-4] += 0.5f;
//				energy -= 5f;
			}

		}

//		if (ground.GetContactList != null) {
//			energy = 0;
//		}
		
		static if (m != m.cpu) {

			if (settings.chaseCam) {
				g_camera.m_center = m_body.GetWorldCenter;
			}

			if (settings.foodCam) {
				g_camera.m_center = m_food.GetWorldCenter;
			}

//			foreach(i; 1 .. foodCount) {
//				g_debugDraw.DrawPoint(spawns[i], 10.0f,  b2Color(255, 0, 0));
//				auto textPos = spawns[i];
//				textPos.x += 1;
//				textPos.y -= 1;
//				g_debugDraw.DrawString(textPos,to!string(i));
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
		
		static if (m != m.user) {
			if (energy <= 0 || sleepCounter > sleepAllowance) {
				if (bestProx > 0) {
					network.fitness += bestProx;
				}
				done = true;
			}
		}
	}
	
	static NeuralTest Create()
	{
		return new typeof(this);
	}
	
	static b2Vec2[] createSpawns(Settings* set)
	{
		b2Vec2[] toReturn;
		toReturn.length = 20;

		float range = 20;
		foreach(i,ref spawn; toReturn) 
		{
			spawn.x = uniform(-range,range);
			spawn.y = uniform(-range,range);
		}
		return toReturn;
	}
	static NetConf getNetConf()
	{
		return NetConf(frontConeEyes.length + 3 + 4,[30],3);
	}
}

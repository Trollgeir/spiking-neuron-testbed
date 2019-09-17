module tests.dpercept;

import dbox.common;
import dbox.dynamics;
import dbox.collision.shapes;
import deimos.glfw.glfw3;
import framework.debug_draw;
import framework.test;
import tests.test_entries : mode;
import network.network;
import std.conv : to;
import std.stdio;

class DPercept(mode m) : NeuralTest
{
	b2Body* ground;
	size_t sleepAllowance = 10;
	int reward = 1000;
	float discount = 0.5;
	enum squareSideL = 60;
	size_t eyeCounter;
	EyeClusterProx eyes;

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
		settings.foodRadius = 0.5f;

		if(settings.IF) network.tDecay[] = 0;

		if(settings.helperParams)
		{
			network.mDecay[0] = 0.5155;
			network.tDecay[0] = 0.1779f;
			network._inputEquil[0] = 0.1778f;
		}

		if(settings.sensorClones)
		{
			foreach(i; 0 .. frontConeEyes(settings.triRay).length) {
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
		energy = reward;

		
		eyes = new EyeClusterProx(60f, frontConeEyes(settings.triRay));
		//spawn first pickup from the spawns array
		
		spawnPickup(spawns[0]);
		
		auto shape = new b2EdgeShape();
		b2FixtureDef sd;
		sd.shape       = shape;
		sd.density     = 0.0f;
		
		{
			b2BodyDef bd;
			bd.position.Set(0.0f, 0.0f);
			ground = m_world.CreateBody(&bd);
			
			// Left vertical
			shape.Set(b2Vec2(-squareSideL/2, -squareSideL/2), b2Vec2(-squareSideL/2, squareSideL/2));
			ground.CreateFixture(&sd);
			
			// Right vertical
			shape.Set(b2Vec2(squareSideL/2, -squareSideL/2), b2Vec2(squareSideL/2, squareSideL/2));
			ground.CreateFixture(&sd);
			
			//Top horizontal
			shape.Set(b2Vec2(-squareSideL/2, squareSideL/2), b2Vec2(squareSideL/2, squareSideL/2));
			ground.CreateFixture(&sd);
			
			// Bottom horizontal
			shape.Set(b2Vec2(-squareSideL/2, -squareSideL/2), b2Vec2(squareSideL/2, -squareSideL/2));
			ground.CreateFixture(&sd);
		} 

		// Using the last spawnlocation for the creature
		m_body.SetTransform(spawns[$-1].position,0);
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
		if (CBdist < foodShape.m_radius+0.5) {
			++foodCount;
			energy += reward*(discount^^foodCount);
			if (foodCount > spawns.length - 2) foodCount = 0;
			m_food.SetTransform((spawns[foodCount].position),0);
		}

		static if (m != m.user) {

			eyes.process;
			network.tick(settings);

			if(settings.paceMaker) network.inputs[$-1] += network.reflex;
			energy -= 0.1;	


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
		}
		
		static if (m != m.cpu) {

			if (settings.chaseCam) {
				g_camera.m_center = m_body.GetWorldCenter;
			}

			if (settings.foodCam) {
				g_camera.m_center = m_food.GetWorldCenter;
			}

			{
				float rangeToBody = b2Distance(m_food.GetWorldCenter,m_body.GetWorldCenter);
				b2Vec2 lastFoodPos = foodCount > 0 ? spawns[foodCount-1].position : b2Vec2();
				float nextFoodMaxDist = b2Distance(m_food.GetWorldCenter,lastFoodPos);
				float prox = (nextFoodMaxDist - rangeToBody) / nextFoodMaxDist;
				if (prox < 0) prox = 0;
				bestProx = prox;
			}

			foreach(i; 0 .. foodCount) {
				g_debugDraw.DrawSolidCircle(spawns[i].position, settings.foodRadius, b2Vec2(), b2Color(255f, 0f, 0f, 0.5f));
				auto textPos = spawns[i].position;
				textPos.x += 1;
				textPos.y -= 1;
				g_debugDraw.DrawString(textPos,to!string(i+1));
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
				foreach(outputValue; network.outputs) {
					++creatureD.x;
					g_debugDraw.DrawPoint(creatureD, 10.0f, b2Color(outputValue, outputValue, outputValue)); //Input firing HUD
				}
			}
		}
		
		static if (m == m.cpu) {
			if (energy <= 0 || sleepCounter > sleepAllowance) 
			{
				if(sleepCounter < sleepAllowance)
					network.fitness = calcFitness();
				done = true;
			}
		}
		static if(m == m.render) {
			if(!settings.infEnergy)
				if (energy <= 0)
					done = true;
		}
	}

	float calcFitness()
	{
		float fitness = 0;
		float rangeToBody = b2Distance(m_food.GetWorldCenter,m_body.GetWorldCenter);
		b2Vec2 lastFoodPos = foodCount > 0 ? spawns[foodCount-1].position : spawns[$-1].position;
		float nextFoodMaxDist = b2Distance(m_food.GetWorldCenter,lastFoodPos);
		float prox = (nextFoodMaxDist - rangeToBody) / nextFoodMaxDist;
		if (prox < 0) prox = 0;
	
		return prox + foodCount;
	}
	
	static NeuralTest Create()
	{
		return new typeof(this);
	}

	import framework.test : Spawn;
	static Spawn[] createSpawns(Settings* set)
	{
		Spawn[] toReturn;
		float range = 0.8f * squareSideL/2;
		toReturn.length = 30;
		foreach(i,ref spawn; toReturn) {
			spawn.position.x = uniform(-range,range);
			spawn.position.y = uniform(-range,range);
		}
		return toReturn;
	}

	class EyeClusterProx
	{
		float[] angles;
		float32 creature_angle;
		b2Vec2 creature_position;
		float32 eyeLength;
		
		this(float length, float[] angles)
		{
			this.angles = angles;
			import core.stdc.math;
			this.eyeLength = sqrt(squareSideL^^2+squareSideL^^2);
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
				
				if (cb.m_hit) {
					auto dist = b2Distance(cb.m_point,creature_position);
					float maxDist = sqrt(squareSideL^^2+squareSideL^^2);
					proximity = 1 - (dist / maxDist);
					if (proximity < 0) proximity = 0;
					cb.m_hit = false;
				}
				
				network.inputs[i] += proximity;
				
				static if (m != m.cpu) {
					//Input firing HUD
					g_debugDraw.DrawSegment(creature_position, cb.m_point, b2Color(proximity, proximity, proximity));
					if(settings.drawSensor)
					{
						float tempy = i;
						b2Vec2 position = b2Vec2(-tempy+3f,33);
						g_debugDraw.DrawPoint(position, 15f, b2Color(proximity, proximity, proximity)); 
						position.y -= 2;
						bool s = network._spikes[i];
						g_debugDraw.DrawPoint(position, 15f, b2Color(s,s,s));
					}
					if (m == m.user)
						writeln(proximity);
				}
			}
		}
	}

	static NetConf getNetConf()
	{
		return NetConf(frontConeEyes(main.settings.triRay).length+1,[3],2);
	}
}

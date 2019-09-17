module tests.pathing;

import dbox.common;
import dbox.collision.shapes.b2polygonshape;
import dbox.dynamics.b2body;
import dbox.dynamics.b2fixture;
import deimos.glfw.glfw3;
import framework.debug_draw;
import framework.test;
import tests.test_entries : mode;
import network.network;
import std.conv : to;
import std.stdio;

class Pathing(mode m) : NeuralTest
{
	size_t foodCount;
	size_t sleepAllowance = 10;
	int reward;
	float discount;
	EyeClusterProx eyes;
	b2Body*[] _creatures;
	SNN[] networks;
	bool endOfFood;
	b2Vec2 clickedPoint;
	RayCastClosestCallback[] cbs;
	bool keyInput;
	b2Vec2 stuckPos;
	
	enum totalFoodAmount = 20;
	enum foodDistance = 400;
	enum smellNeurons = 2;
	enum pacemaker = 1;
	
	this()
	{
		static if (m != m.cpu) {
			m_world.SetDebugDraw(g_debugDraw);
			network = BGE.getSample();
			settings = &main.settings;
			spawns = createSpawns(settings);
			initialize;
			if(settings.creatureCount > 1)
				renderInit();
		}
	}

	override void MouseDown(b2Vec2 p) 
	{
		if(settings.clickMove) 
		{
			spawns[foodCount].position = p;
			settings.foodRadius = 10f;
		}
		super.MouseDown(p);
	}

	static if (m != m.cpu) {
		override void Keyboard(int key)
		{
			switch (key)
			{
				case GLFW_KEY_W:
				{
					auto p = m_body.GetPosition;
					b2Vec2 f = m_body.GetWorldVector(b2Vec2(-1.5f, 5f));
					m_body.ApplyLinearImpulse(f,p,true);

					f = m_body.GetWorldVector(b2Vec2(1.5f, 5f));
					m_body.ApplyLinearImpulse(f,p,true);
					keyInput = true;
				}
					break;
					
				default:
					break;
			}
		}
	}

	override void initialize()
	{
		eyes = new EyeClusterProx(60f, frontConeEyes(settings.triRay));
		settings.foodRadius = 5;
		reward = cast(int)settings.reward;
		discount = settings.discount;
		stuckPos = m_body.GetPosition;

		energy = reward;
		
		if(settings.helperParams)
		{
			network.mDecay[0..2] = 0.333f;
			network.tDecay[0..2] = 1f;
			network._inputEquil[0..2] = 0;
		}
		
		if(settings.sensorClones)
		{
			// Nose
			network.mDecay[0..2] = network.mDecay[0];
			network.tDecay[0..2] = network.tDecay[0];
			network._inputEquil[0..2] = network._inputEquil[0];

//			network.mDecay[3..6] = network.mDecay[3];
//			network.tDecay[3..6] = network.tDecay[3];
//			network._inputEquil[3..6] = network._inputEquil[3];

			// Eyes
//			network.mDecay[9..11] = network.mDecay[9];
//			network.tDecay[9..11] = network.tDecay[9];
//			network._inputEquil[9..11] = network._inputEquil[9];
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

			// L1:
			
			// -------------------------------
			network._inputEquil[0] = 0;
			network.mDecay[0] = 0;
			network.tDecay[0] = 1;
			network.weights[0] = [-0.812256, 0.68874, 0.0532071, -0.00316059];
			
			// -------------------------------
			network._inputEquil[1] = 0;
			network.mDecay[1] = 0.456002;
			network.tDecay[1] = 0.873833;
			network.weights[1] = [-0.0529251, 0, 0, -0.0132211];
			
			// -------------------------------
			network._inputEquil[2] = 0.50939;
			network.mDecay[2] = 0.129433;
			network.tDecay[2] = 0.103937;
			network.weights[2] = [-0.998814, 0.151306, -0.767294, 0.98861];
			
			// -------------------------------
			network._inputEquil[3] = 0.503243;
			network.mDecay[3] = 0;
			network.tDecay[3] = 0;
			network.weights[3] = [-0.522463, -0.0391994, -0.117415, 0.591036];
			
			// -------------------------------
			network._inputEquil[4] = 0.0387589;
			network.mDecay[4] = 0;
			network.tDecay[4] = 0.22635;
			network.weights[4] = [0.484228, -0.60793, -0.629262, 0];
			
			// -------------------------------
			network._inputEquil[5] = 0.893363;
			network.mDecay[5] = 0.300884;
			network.tDecay[5] = 0.943124;
			network.weights[5] = [0.0622029, 0.258805, 0.169229, -0.95007];
			
			// -------------------------------
			network._inputEquil[6] = 0;
			network.mDecay[6] = 0.170836;
			network.tDecay[6] = 0.375684;
			network.weights[6] = [0, 0, 0.0145852, -0.315957];
			
			
			// L2:
			
			// -------------------------------
			network.mDecay[7] = 0.622092;
			network.tDecay[7] = 0.120611;
			network.weights[7] = [-1, -0.929465, 0.294711, -0.805066, -0.475688, -0.0398117, -0.0172607];
			
			// -------------------------------
			network.mDecay[8] = 0.116914;
			network.tDecay[8] = 0.0940128;
			network.weights[8] = [0, 0.768624, -0.00829733, -0.762184, -0.135832, 0, 0.0111028];
			
			// -------------------------------
			network.mDecay[9] = 0;
			network.tDecay[9] = 1;
			network.weights[9] = [0, 0, 0, 0, 0, 0.308267, -0.0173794];
			
			// -------------------------------
			network.mDecay[10] = 0.311936;
			network.tDecay[10] = 1;
			network.weights[10] = [0, 0, -0.180217, 0.576699, 0.00174343, 0.00340275, 0];
			
			network.reflex = -0.244136;

			network.flush();
		}

		spawnObstacles(spawns[totalFoodAmount..$]);
	}

	void renderInit()
	{
		networks.length = _creatures.length = cbs.length = settings.creatureCount;
		foreach(i,ref n; networks) {
			n = network.dup();
			n.flush;
			cbs[i] = new RayCastClosestCallback();
		}
		
		{
			b2Transform xf1;
			xf1.q.Set(0.3524f * b2_pi);
			xf1.p = xf1.q.GetXAxis();
			
			b2Vec2[3] vertices;
			vertices[0] = b2Mul(xf1, b2Vec2(-1.0f, 0.0f));
			vertices[1] = b2Mul(xf1, b2Vec2(1.0f, 0.0f));
			vertices[2] = b2Mul(xf1, b2Vec2(0.0f, 0.5f));
			
			b2PolygonShape poly1 = new b2PolygonShape();
			poly1.Set(vertices);
			
			b2FixtureDef sd1;
			sd1.shape   = poly1;
			sd1.density = 2.0f;
			if (!settings.collision) sd1.filter.groupIndex = -1;
			
			b2Transform xf2;
			xf2.q.Set(-0.3524f * b2_pi);
			xf2.p = -xf2.q.GetXAxis();
			
			vertices[0] = b2Mul(xf2, b2Vec2(-1.0f, 0.0f));
			vertices[1] = b2Mul(xf2, b2Vec2(1.0f, 0.0f));
			vertices[2] = b2Mul(xf2, b2Vec2(0.0f, 0.5f));
			
			b2PolygonShape poly2 = new b2PolygonShape();
			poly2.Set(vertices);
			
			b2FixtureDef sd2;
			sd2.shape   = poly2;
			sd2.density = sd1.density;
			sd2.filter.groupIndex = sd1.filter.groupIndex;
			
			
			b2BodyDef bd;
			bd.type = b2_dynamicBody;
			bd.angularDamping = 10.0f;
			bd.linearDamping  = 10f;
			
			foreach(i; 0 .. _creatures.length) {
				import std.math;
				import core.stdc.math;
				float32 a = uniform(0,PI*2f);
				b2Vec2 pos = b2Vec2((uniform(0.9f,settings.creatureCount/10)) * cosf(a), (uniform(0.9f,settings.creatureCount/10)) * sinf(a));
				bd.position.Set(pos);
				bd.angle      = uniform(0f,2f*b2_pi);
				bd.allowSleep = true;
				
				_creatures[i] = m_world.CreateBody(&bd);
				_creatures[i].CreateFixture(&sd1);
				_creatures[i].CreateFixture(&sd2);
			}
		}
	}
	
	//Main step loop.
	override void Step(Settings* settings)
	{
		keyInput = false;
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
				network.inputs[$-1+i] += network.reflex;


		if(settings.foodRadius < 0.5f) 
		{
			++foodCount;
			settings.foodRadius = 10;
			if (foodCount >= totalFoodAmount) foodCount = 0;
		}

		bool sleep;

		float overlap = b2Distance(spawns[foodCount].position,m_body.GetWorldCenter);
		if (overlap < settings.foodRadius+0.5) {
			if(!settings.clickMove)
			{
				++foodCount;
				energy += reward*(discount^^foodCount);
				if (foodCount > totalFoodAmount - 1) endOfFood = true;
			}
			else 
			{
				import std.math : sqrt;
				if(settings.foodRadius > 0) settings.foodRadius -= (0.01f* (1 - settings.foodRadius/20)^^2);
				sleep = true;
			}
		}

		float smellSense = 0;
		if(!sleep)
		{
			import std.math : sqrt;
			{
				auto ca =  m_body.GetAngle;
				auto cp = m_body.GetPosition;
				import core.stdc.math;
				float32 a = ca + (1.5)*(b2_pi);
				b2Vec2 p;
				p = cp + b2Vec2((settings.antLength) * cosf(a), (settings.antLength) * sinf(a));
				smellSense = b2Distance(spawns[foodCount].position,p);
				
				if(settings.gradient)
				{
					import std.math : E, pow, sqrt;
					auto temp1 = pow(smellSense,2.5f);
					auto temp2 = pow((2 * (foodDistance/2)),2.5f) / 10;
					smellSense = pow(E,-(temp1/temp2));
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
					smellSense *= spawns[foodCount].alpha;
					
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

			if(settings.useEyes)
			{
				auto eyeOutput = eyes.process(m_body.GetAngle, m_body.GetPosition,cb, true);
				foreach(i,output; eyeOutput)
				{
					network.inputs[i+smellNeurons] = output;
				}
			}

			if(auto c = m_body.GetContactList)
				if(c.contact.IsTouching)
					network.inputs[5] = 0.5f;

			network.tick(settings);

			energy -= 0.1;
			
			b2Vec2 p = m_body.GetPosition;

			if(!keyInput)
			{
				if (network.outputs[2]) {
					b2Vec2 f = m_body.GetWorldVector(b2Vec2(-1.5f, 10f));
					m_body.ApplyLinearImpulse(f,p,true);
					energy -= 10;
				}
//				else 
					if (network.outputs[0]) {
						b2Vec2 f = m_body.GetWorldVector(b2Vec2(-1.5f, -10f));
						m_body.ApplyLinearImpulse(f,p,true);
						energy -= 5;
					}
			

				if (network.outputs[3]) {
					b2Vec2 f = m_body.GetWorldVector(b2Vec2(1.5f, 10f));
					m_body.ApplyLinearImpulse(f,p,true);
					energy -= 10;
				}
//				else
					if (network.outputs[1]) {
						b2Vec2 f = m_body.GetWorldVector(b2Vec2(1.5f, -10f));
						m_body.ApplyLinearImpulse(f,p,true);
						energy -= 5;
					}

			}
		}

	

		static if (m != m.cpu) {
			multiTick();

			if (settings.chaseCam) {
				g_camera.m_center = m_body.GetWorldCenter;
			}
			if (settings.foodCam) {
				g_camera.m_center = spawns[foodCount].position;
			}

			g_debugDraw.DrawSolidCircle(spawns[foodCount].position, settings.foodRadius, b2Vec2(), b2Color(0f, 255f, 0f, 0.5f));

			if(!settings.clickMove)
			{
				foreach(i; 0 .. foodCount) {
					g_debugDraw.DrawSolidCircle(spawns[i].position, settings.foodRadius, b2Vec2(), b2Color(255f, 0f, 0f, 0.5f));
					auto textPos = spawns[i].position;
					textPos.x += 6;
					textPos.y -= 9;
					g_debugDraw.DrawString(textPos,to!string(i+1));
				}
			}

			{
				float rangeToBody = b2Distance(spawns[foodCount].position,m_body.GetWorldCenter);
				b2Vec2 lastFoodPos = foodCount > 0 ? spawns[foodCount-1].position : b2Vec2();
				float nextFoodMaxDist = b2Distance(spawns[foodCount].position,lastFoodPos);
				float prox = (nextFoodMaxDist - rangeToBody) / nextFoodMaxDist;
				if (prox < 0) prox = 0;
				bestProx = prox;
			}
			
			if(settings.drawTrace) trace ~= m_body.GetWorldCenter;
			
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
			
//			if (settings.drawOutputs) {
//				creatureD.y -= 1;
//				creatureD.x -= (network.outputs.length/2f) - 0.5f;
//				foreach(s; network.outputs) {
//					++creatureD.x;
//
//					b2Transform xf1;
//					xf1.q.Set(0.3524f * b2_pi);
//					xf1.p = xf1.q.GetXAxis();
//
//					g_debugDraw.DrawPoint(creatureD, 20.0f,  b2Color()); //Input firing HUD
//					g_debugDraw.DrawPoint(creatureD, 10.0f,  b2Color(s,s,s)); //Input firing HUD
//				}
//			}

			if(settings.drawSensor)
			{
				b2Vec2 center;

				center.y = g_camera.m_center.y - 14*g_camera.m_zoom;
				center.x = g_camera.m_center.x - 15*g_camera.m_zoom;
				g_debugDraw.DrawString(center, "Smell input: " ~ to!string(smellSense));


				center.y = g_camera.m_center.y - 16*g_camera.m_zoom;
				center.x = g_camera.m_center.x - 15*g_camera.m_zoom;
				g_debugDraw.DrawString(center, "Sensor neurons");

				foreach(i; 0 .. network.inputs.length) {
					center.x = g_camera.m_center.x- (network.inputs.length/2 + 1.5)*g_camera.m_zoom + i*1.5*g_camera.m_zoom;
					bool s = network._spikes[i];
					g_debugDraw.DrawPoint(center, 30.0f,  b2Color(0.5,0.5,0.5));
					g_debugDraw.DrawPoint(center, 15f, b2Color(s,s,s));
				}
//				center.y = g_camera.m_center.y - 17.5*g_camera.m_zoom;
//				center.x = g_camera.m_center.x - 15*g_camera.m_zoom;
//				g_debugDraw.DrawString(center, "Interneurons");
//
//				foreach(i; 0 .. network._layers[1]) {
//					center.x = g_camera.m_center.x- (network._layers[1]/2 + 0.75)*g_camera.m_zoom + i*1.5*g_camera.m_zoom;
//					bool s = network._spikes[network.inputs.length+i];
//					g_debugDraw.DrawPoint(center, 30.0f,  b2Color(0.5,0.5,0.5));
//					g_debugDraw.DrawPoint(center, 15f, b2Color(s,s,s));
//				}

				center.y = g_camera.m_center.y - 18*g_camera.m_zoom;
				center.x = g_camera.m_center.x - 15*g_camera.m_zoom;
				g_debugDraw.DrawString(center, "Motor neurons");

				foreach(i,output; network.outputs) {
					center.x = g_camera.m_center.x - (network.outputs.length/2 + 0.3)*g_camera.m_zoom + i*1.5*g_camera.m_zoom;
					g_debugDraw.DrawPoint(center, 30.0f,  b2Color(0.5,0.5,0.5));
					g_debugDraw.DrawPoint(center, 15f, b2Color(output,output,output));
				}
			}
		}

		bool award = true;
		if(m_stepCount % 50 == 0)
		{
			float distance = b2Distance(stuckPos, m_body.GetPosition);
			if(distance < 1)
			{
				award = false;
				energy = 0;
			}
			stuckPos = m_body.GetPosition;
		}

		
		static if (m == m.cpu) {
			if (energy <= 0 || (sleepCounter > sleepAllowance) || endOfFood == true) {
				if(sleepCounter < sleepAllowance)
					network.fitness += calcFitness(award);
				done = true;
			}
		}
		static if(m == m.render)
		{
			if(settings.infEnergy) energy = 0;
			else
				if (energy <= 0)	
					done = true;

			if(endOfFood == true)
				done = true;
		}
	}
	
	float calcFitness(bool award)
	{
		float prox = 0;
		if (settings.proxFitness)
		{
			float rangeToBody = b2Distance(spawns[foodCount].position,m_body.GetWorldCenter);
			b2Vec2 lastFoodPos = foodCount > 0 ? spawns[foodCount-1].position : b2Vec2();
			float nextFoodMaxDist = b2Distance(spawns[foodCount].position,lastFoodPos);
			prox = (nextFoodMaxDist - rangeToBody) / nextFoodMaxDist;
			if (prox < 0) prox = 0;
		}
		if(!award)
			return 0;
			//foodCount /= 2;
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
		toReturn.length = totalFoodAmount + (totalFoodAmount*set.obstacleCount);
		import std.math : PI;
		import core.stdc.math;
		import std.random : uniform01;
		size_t j;
		size_t counter;
		foreach(i,ref spawn; toReturn[0 .. $]) {
			if(i == 0)
			{
//				spawn.isStatic = false;
				float a = uniform(0,PI*2f);
				float temp = uniform(0,range);
				spawn.position = b2Vec2(temp * cosf(a), temp * sinf(a));
				spawn.alpha = uniform01;
				spawn.food = true;
				continue;
			}
			// Food
			if(i < totalFoodAmount)
			{
				// Spawn location for food
				float a = uniform(0,PI*2f);
				float temp = uniform(0,range);
				spawn.position = toReturn[i-1].position + b2Vec2(temp * cosf(a), temp * sinf(a));

				// Alpha value (intensity)
				spawn.alpha = uniform01;
				spawn.food = true;
			}
			else
			{
				if(counter > set.obstacleCount)
				{
					counter = 0;
					++j;
				}
				// Spawn location for objects
//				spawn.isStatic = false;
				spawn.size = uniform(1f,40f);
				spawn.rotation = uniform(0f,b2_pi*2f);
				import framework.test : objType;
				spawn.type = cast(objType)uniform(0,3);
				// Assume collision
				bool collision = true;

				while (collision == true)
				{
					collision = false;
					float a = uniform(0,PI*2f);
					float temp = uniform(0,range);
					spawn.position = toReturn[j].position + b2Vec2(temp * cosf(a), temp * sinf(a));

					foreach(foodSpawn; toReturn[0 .. totalFoodAmount])
					{
						float overlap = b2Distance(foodSpawn.position, spawn.position);
						if(spawn.type == objType.square)
						{
							if (overlap < (spawn.size*sqrt(2)) + 5) collision = true;
							float overlapSpawn = b2Distance(b2Vec2(), spawn.position);
							if (overlapSpawn < (spawn.size*sqrt(2)) + 5) collision = true;
						}
						else
						{
							if (overlap < spawn.size + 5) collision = true;
							float overlapSpawn = b2Distance(b2Vec2(), spawn.position);
							if (overlapSpawn < spawn.size + 5) collision = true;
						}
					}

					foreach(objectSpawn; toReturn[totalFoodAmount .. i])
					{
						float overlap = b2Distance(objectSpawn.position, spawn.position);
						if (overlap < spawn.size + 5) collision = true;
					}
				}
				++counter;
			}
		}
		return toReturn;
	}
	
	static NetConf getNetConf()
	{
		size_t outputs = 4;
		return NetConf(pacemaker+smellNeurons+3+1,[],outputs);
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
			this.eyeLength = 10;
		}

		float[] process(float _angle, b2Vec2 _position, RayCastClosestCallback callback, bool draw)
		{
			float[] outputArray;
			outputArray.length = angles.length;
						
			foreach(i,angle; angles) {
				import core.stdc.math;
				float32 a = _angle + (angle)*(b2_pi);
				b2Vec2 p = _position + b2Vec2(eyeLength * cosf(a), eyeLength * sinf(a));

				m_world.RayCast(callback,_position,p);
				float proximity = 0;

				static if (m == m.render) {
					if(draw && settings.drawRays)
					{
						if(callback.m_hit == true)
						{
							g_debugDraw.DrawSegment(_position, callback.m_point, b2Color(1f, 0f, 0f));
						}
							
						else
							g_debugDraw.DrawSegment(_position, p, b2Color(1, 1, 1));
					}
				}

				if (callback.m_hit) {
					auto dist = b2Distance(callback.m_point,_position);
					proximity = 1 - (dist / eyeLength);
					if (proximity < 0) proximity = 0;
					callback.m_hit = false;
				}
				outputArray[i] = proximity;
			}
			return outputArray;
		}
	}

	void multiTick()
	{
		import std.parallelism;
		import std.datetime;

//		StopWatch test = StopWatch(AutoStart.yes);
//		writeln(test.peek.msecs);

		foreach(i,net; parallel(networks[]))
		{
			float overlap = b2Distance(spawns[foodCount].position,_creatures[i].GetWorldCenter);
			if (overlap < settings.foodRadius+0.5)
			{
				import std.math : sqrt;
				if(settings.foodRadius > 0) settings.foodRadius -= (0.01f* (1 - settings.foodRadius/20)^^2);
				continue;
			}

			float smellSense = 0;
			{
				auto ca =  _creatures[i].GetAngle;
				auto cp = _creatures[i].GetPosition;
				import core.stdc.math;
				float32 a = ca + (1.5)*(b2_pi);
				b2Vec2 p;
				p = cp + b2Vec2((settings.antLength) * cosf(a), (settings.antLength) * sinf(a));
				smellSense = b2Distance(spawns[foodCount].position,p);
				
				if(settings.gradient)
				{
					import std.math : E, pow, sqrt;
					auto temp1 = pow(smellSense,2.5f);
					auto temp2 = pow((2 * (foodDistance/2)),2.5f) / 10;
					smellSense = pow(E,-(temp1/temp2));
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
					smellSense *= spawns[foodCount].alpha;
				}
				
				import network.randNormal : randNormal;
				if(settings.noise > 0)
					smellSense = randNormal!float(smellSense,settings.noise,-1f,1f);
				
				if(settings.onNeuron) net.inputs[0] += smellSense;
				if(settings.offNeuron && smellNeurons > 1)	net.inputs[1] += 1 - smellSense;
			}
			
			if(pacemaker && settings.paceMaker) net.inputs[$-1] += net.reflex;

			if(settings.useEyes)
			{
				auto eyeOutput = eyes.process(_creatures[i].GetAngle, _creatures[i].GetPosition, cbs[i], false);
				foreach(j,output; eyeOutput)
				{
					net.inputs[j+smellNeurons] = output;
				}
			}

			if(auto c = _creatures[i].GetContactList)
				if(c.contact.IsTouching)
					net.inputs[5] = 0.5f;

			net.tick(settings);	

			b2Vec2 p = _creatures[i].GetPosition;
			

			if (net.outputs[2]) {
				b2Vec2 f = _creatures[i].GetWorldVector(b2Vec2(-1.5f, 5f));
				_creatures[i].ApplyLinearImpulse(f,p,true);
			}
			else
				if (net.outputs[0]) {
					b2Vec2 f = _creatures[i].GetWorldVector(b2Vec2(-1.5f, -10f));
					_creatures[i].ApplyLinearImpulse(f,p,true);
				}
			if (net.outputs[3]) {
				b2Vec2 f = _creatures[i].GetWorldVector(b2Vec2(1.5f, 5f));
				_creatures[i].ApplyLinearImpulse(f,p,true);
			}
			else
				if (net.outputs[1]) {
					b2Vec2 f = _creatures[i].GetWorldVector(b2Vec2(1.5f, -10f));
					_creatures[i].ApplyLinearImpulse(f,p,true);
				}
		}
	}
}

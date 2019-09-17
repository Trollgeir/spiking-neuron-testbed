module tests.klinotaxi;

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

class Klinotaxi(mode m) : NeuralTest
{
	size_t foodCount;
	float boxDiminish;
	float32 creature_a;
	b2Vec2 creature_p;
	size_t sleepAllowance;
	size_t reward;
	b2Body*[] _creatures;
	SNN[] networks;
	import std.file;
	File chemoLog;
	size_t tick;

	enum smellNeurons = 1;
	enum foodDistance = 250; 
	enum pacemaker = 0;
	
	this()
	{
		static if (m != m.cpu) {
			m_world.SetDebugDraw(g_debugDraw);
			network = BGE.getSample();
			settings = &main.settings;
			spawns = createSpawns(settings);
			initialize();
			if(settings.creatureCount > 1)
				renderInit();
		}
	}
	
	override void initialize()
	{
		//		m_world.SetGravity(spawns[$-1]);
//		if(pacemaker)network.tDecay[$-1] = 0;

		if(settings.helperParams)
		{
			network.mDecay[0] = 0f;
			network.tDecay[0] = 1f;
			network._inputEquil[0] = 0f;
		}

		if(settings.sensorClones)
		{
			network.mDecay[0..smellNeurons] = network.mDecay[0];
			network.tDecay[0..smellNeurons] = network.tDecay[0];
			network._inputEquil[0..smellNeurons] = network._inputEquil[0];
		}

		if(settings.motorClones)
		{
			network.mDecay[$ - network.outputs.length .. network._neuron_c] = network.mDecay[$ - network.outputs.length];
			network.tDecay[$ - network.outputs.length .. network._neuron_c] = network.tDecay[$ - network.outputs.length];
		}
		
		if(settings.IF) network.tDecay[network.inputs.length .. $] = 0;

		if(settings.bestNetwork)
		{
			//			// 2,[2],2
			if(getNetConf.hidden.length > 0)
			{
				network._inputEquil[0] = 0;
				network._inputEquil[1] = 0;
				
				network.mDecay[0] = 0;
				network.mDecay[1] = 0; //0.475129;
				network.mDecay[2] = 0.876913;
				network.mDecay[3] = 0;
				network.mDecay[4] = 0.346107;
				network.mDecay[5] = 0;
				
				network.tDecay[0] = 1;
				network.tDecay[1] = 1;
				network.tDecay[2] = 0.981198;
				network.tDecay[3] = 0.924545;
				network.tDecay[4] = 0.155488;
				network.tDecay[5] = 0.473154;
				
				network.weights[0] = [0.90386, 0.758089];
				network.weights[1] = [0, 0.852652];
				network.weights[2] = [0.81224, 0.644401];
				network.weights[3] = [0.697886, -0.86737];
				network.weights[4] = [0,0];
				network.weights[5] = [0.0467544, -0.00427933];
			}
			else
			{	
				// 1,[],2
				
//				network.mDecay[0] = 0.333425;
//				network.tDecay[0] = 1;
//				network._inputEquil[0] = 0;
//				network.weights[0] = [-0.793871, -0.185384];
//				
//				network.mDecay[1] = 0.980605;
//				network.tDecay[1] =  0.767046;
//				
//				network.mDecay[2] = 0.827269;
//				network.tDecay[2] = 0.0492543;
				network.mDecay[0] = 0.333425;
				network.tDecay[0] = 1;
				network._inputEquil[0] = 0;
				network.weights[0] = [0.0700205, -0.400718];
				
				network.mDecay[1] = 1;
				network.tDecay[1] = 0;
				
				network.mDecay[2] = 0.692516;
				network.tDecay[2] = 0.0904454;

			}
		}


		reward = 1000;
		boxDiminish = reward * 0.1f;	//diminshing returns for energy per food pickup
		sleepAllowance = 10;
		energy = reward;

		m_body.SetTransform(b2Vec2(0,0),spawns[foodCount].position.y);

		settings.foodRadius = foodDistance * 0.02222f;

		spawnPickup(Spawn(b2Vec2(foodDistance,0)));
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
					b2Vec2 f = m_body.GetWorldVector(b2Vec2(0.5f, -10f));
					b2Vec2 p = m_body.GetWorldPoint(b2Vec2(0.0f, 3.0f));
					m_body.ApplyLinearImpulse(f,p,true);
					energy -= 10;
					
				}
					break;
					
				case GLFW_KEY_D:
				{
					b2Vec2 f = m_body.GetWorldVector(b2Vec2(-0.5f, -10f));
					b2Vec2 p = m_body.GetWorldPoint(b2Vec2(0.0f, 3.0f));
					m_body.ApplyLinearImpulse(f,p,true);
					energy -= 10;
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

		float overlap = b2Distance(m_food.GetWorldCenter,m_body.GetWorldCenter);
		if (overlap < foodShape.m_radius+1 && settings.creatureCount < 1) {
			++foodCount;
			network.fitness += energy;
			static if (m == m.cpu )
				done = true;
			else
			{
				if(settings.infEnergy)
				{
					m_body.m_angularVelocity = 0;
					m_body.m_linearVelocity = b2Vec2(0,0);
					b2Vec2 pos = b2Vec2(0,0);
					m_body.SetTransform(pos,uniform(0f,2f*b2_pi));
					network.flush;
				}
				else done = true;
			}
		}

		float proxFitness = 0;

		auto maxDistance = b2Distance(b2Vec2(0,0), m_food.GetPosition);
		auto currentDistance = b2Distance(m_body.GetPosition, m_food.GetPosition);
		proxFitness = 1 - (currentDistance / maxDistance);
		if(proxFitness < 0) proxFitness = 0;




		float smellSense = 0;
		{
			auto ca =  m_body.GetAngle;
			auto cp = m_body.GetPosition;
			import core.stdc.math;
			float32 a = ca + (1.5)*(b2_pi);
			b2Vec2 p;
			p = cp + b2Vec2((settings.antLength) * cosf(a), (settings.antLength) * sinf(a));
			
			smellSense = b2Distance(m_food.GetWorldCenter,p);

			if(settings.gradient)
			{
				import std.math : E, pow, sqrt;
				auto temp1 = pow(smellSense,2.5f);
				auto temp2 = pow((2 * (foodDistance/2)),2.5f) / 10;
				smellSense = pow(E,-(temp1/temp2));

//				static if(m == m.render)
//				{
//					chemoLog = File("chemotaxi.dat","a");
//					chemoLog.writeln(smellSense);
//					chemoLog.close();
//				}

			}
			else
				smellSense = (1 - (smellSense / (foodDistance+50)))*spawns[0].position.x;
			
			if (smellSense < 0) {
				smellSense = 0;
			}
			if (smellSense > 1) {
				smellSense = 1;
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
					if (smellNeurons > 1 && network._spikes[1] > 0)
						g_debugDraw.DrawSolidCircle(p, 0.25f, b2Vec2(), b2Color(255f, 0f, 0f,255f));
				}
			}
		}

		bestProx = smellSense;
		
		static if (m != m.user) {
		
			if(pacemaker && settings.paceMaker)
					network.inputs[$-1] += 0.5f;


			network.tick(settings);

			
			energy -= 1;

			if (network.outputs[0]) {
				b2Vec2 f = m_body.GetWorldVector(b2Vec2(-1.5f, -10f));
				b2Vec2 p = m_body.GetPosition;
				m_body.ApplyLinearImpulse(f,p,true);
			}
			if (network.outputs[1]) {
				b2Vec2 f = m_body.GetWorldVector(b2Vec2(1.5f, -10f));
				b2Vec2 p = m_body.GetPosition;
				m_body.ApplyLinearImpulse(f,p,true);

			}
		}
		
		static if (m != m.cpu) {

			if(settings.creatureCount > 1)
				multiTick();
			
			if (settings.chaseCam) {
				g_camera.m_center = m_body.GetWorldCenter;
			}
			if (settings.foodCam) {
				g_camera.m_center = m_food.GetWorldCenter;
			}

			
			trace ~= m_body.GetWorldCenter;

			if(settings.drawTrace)
			{
				b2Color heat = b2Color(0,1,0);
				
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
					g_debugDraw.DrawPoint(creatureD, 10.0f,  b2Color(outputValue, outputValue, outputValue)); //Input firing HUD
				}
			}

			if(settings.drawSensor)
			{
				struct temp
				{
					float _equil;
					bool _spike;
				}
				temp[] pairs;
				pairs.length = smellNeurons+pacemaker;
				foreach(i,equil_;network._inputEquil[0 .. smellNeurons+pacemaker]) {
					pairs[i]._equil = equil_;
					pairs[i]._spike = network._spikes[i];
				}
				
				import std.algorithm;
				
//				sort!("a._equil < b._equil")(pairs[]);
				
				foreach(i,pair; pairs) {
					b2Vec2 center;
					center.y = g_camera.m_center.y - 24;
					center.x = g_camera.m_center.x - pairs.length/2 + i;
					g_debugDraw.DrawPoint(center, 15f, b2Color(pair._spike, pair._spike, pair._spike)); //Input firing HUD
					if(i == pairs.length-1)
					{
						import std.conv : to;
						string str = to!string(smellSense);
						center.x += 1;
						g_debugDraw.DrawString(center, str);
					}
				}
			}
		}
		static if (m == m.cpu) {
			if (!m_body.IsAwake) {
				++sleepCounter;
			}
			else {
				sleepCounter = 0;
			}
			if (energy <= 0 || (sleepCounter > sleepAllowance)) {

				network.fitness += proxFitness; // b2Distance(b2Vec2(0,0), m_body.GetWorldCenter);
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
	
	static Spawn[] createSpawns(Settings* set)
	{
		Spawn[] toReturn;
		toReturn.length = 2;
		import std.math : PI;
		toReturn[0].position.x = uniform(0.1f,1);
		toReturn[0].position.y = uniform(0,PI*2);
		return toReturn;
	}
	
	static NetConf getNetConf()
	{
		size_t outputs = 2;
		return NetConf(pacemaker+smellNeurons,[],outputs);

	}

	void renderInit()
	{
		networks.length = _creatures.length = settings.creatureCount;
		foreach(ref n; networks) {
			n = network.dup();
			n.flush;
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
				b2Vec2 pos = m_food.GetWorldCenter + b2Vec2((foodDistance) * cosf(a), (foodDistance) * sinf(a));
				bd.position.Set(pos);
				bd.angle      = uniform(0f,2f*b2_pi);
				bd.allowSleep = true;
				
				_creatures[i] = m_world.CreateBody(&bd);
				_creatures[i].CreateFixture(&sd1);
				_creatures[i].CreateFixture(&sd2);
			}
		}
	}

	void multiTick()
	{
		import std.parallelism;
//		foreach(i,net; networks)
//		{
//			float overlap = b2Distance(m_food.GetWorldCenter,_creatures[i].GetWorldCenter);
//			if (overlap < foodShape.m_radius+1) 
//			{
//				import std.math;
//				import core.stdc.math;
//				float32 a = uniform(0,PI*2f);
//				b2Vec2 pos = m_food.GetWorldCenter + b2Vec2((foodDistance) * cosf(a), (foodDistance) * sinf(a));
//				_creatures[i].m_angularVelocity = 0;
//				_creatures[i].m_linearVelocity = b2Vec2(0,0);
//				_creatures[i].SetTransform(pos,uniform(0f,2f*b2_pi));
//				networks[i].flush;
//			}
//		}

		foreach(i,net; parallel(networks[]))
		{
			float smellSense = 0;
			{
				auto ca =  _creatures[i].GetAngle;
				auto cp = _creatures[i].GetPosition;
				import core.stdc.math;
				float32 a = ca + (1.5)*(b2_pi);
				b2Vec2 p;
				p = cp + b2Vec2((settings.antLength) * cosf(a), (settings.antLength) * sinf(a));
				
				smellSense = b2Distance(m_food.GetWorldCenter,p);

				if(settings.gradient)
				{
					import std.math : E, pow;
					auto temp1 = pow(smellSense,2.5f);
					auto temp2 = pow((2 * (foodDistance)),2.5f) / 10;
					smellSense = pow(E,-(temp1/temp2));
				}
				else
					smellSense = (1 - (smellSense / (foodDistance+50)))*spawns[0].alpha;
				
				if (smellSense < 0) {
					smellSense = 0;
				}
				if (smellSense > 1) {
					smellSense = 1;
				}
				
				import network.randNormal : randNormal;
				if(settings.noise > 0)
					smellSense = randNormal!float(smellSense,settings.noise,-1f,1f);

				if(settings.onNeuron) networks[i].inputs[0] += smellSense;
				if(settings.offNeuron) networks[i].inputs[1] += 1 - smellSense;
			}		

			if(pacemaker && settings.paceMaker) networks[i].inputs[$-1] += 0.5f;
			
			networks[i].tick(settings);			

			if (networks[i].outputs[0]) {
				b2Vec2 f = _creatures[i].GetWorldVector(b2Vec2(-1.5f, -10f));
				b2Vec2 p = _creatures[i].GetPosition;
				_creatures[i].ApplyLinearImpulse(f,p,true);
			}
			
			if (networks[i].outputs[1]) {
				b2Vec2 f = _creatures[i].GetWorldVector(b2Vec2(1.5f, -10f));
				b2Vec2 p = _creatures[i].GetPosition;
				_creatures[i].ApplyLinearImpulse(f,p,true);
			}
		}
	}
}

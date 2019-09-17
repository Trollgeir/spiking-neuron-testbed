module tests.stresstest;

import dbox;
import deimos.glfw.glfw3;
import framework.debug_draw;
import framework.test;
import tests.test_entries : mode;
import network.network;
import std.conv : to;
import std.stdio;
import std.random : uniform;

class Stress(mode m) : NeuralTest
{
	b2Vec2[] localSpawns;
	SNN[] networks;
	b2Body*[] _creatures;
	b2Body* ground;

	double time1;
	double time2;

	this()
	{
		static if (m != m.cpu) {
			m_world.DestroyBody(m_body);
			m_world.SetDebugDraw(g_debugDraw);
			settings = &main.settings;
			settings.speed = 0;
			networks.length = _creatures.length = settings.creatureCount;
			foreach(ref n; networks) {
				n = new SNN(getNetConf);
				n.randomize;
				n.flush;
				n.tDecay[0] = 0f;
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
				sd2.isSensor = sd1.isSensor;
				sd2.filter.groupIndex = sd1.filter.groupIndex;

				
				b2BodyDef bd;
				bd.type = b2_dynamicBody;
				bd.angularDamping = 10.0f;
				bd.linearDamping  = 10f;
			


				foreach(i; 0 .. _creatures.length) {
					import std.math;
					auto squared =  sqrt(cast(float)(_creatures.length*50));
					b2Vec2 pos = b2Vec2(uniform(0,squared)-squared/2,uniform(0,squared)-squared/2);
					bd.position.Set(pos);
					bd.angle      = uniform(0f,2f*b2_pi);
					bd.allowSleep = true;
					
					_creatures[i] = m_world.CreateBody(&bd);
					_creatures[i].CreateFixture(&sd1);
					_creatures[i].CreateFixture(&sd2);
				}
			}
//			auto shape = new b2EdgeShape();
//			b2FixtureDef sd;
//			sd.shape       = shape;
//			sd.density     = 0.0f;
//			//sd.restitution = k_restitution;
//			
//			{
//				b2BodyDef bd;
//				bd.position.Set(0.0f, 0.0f);
//				ground = m_world.CreateBody(&bd);
//				
//				// Left vertical
//				shape.Set(b2Vec2(-30.0f, -30.0f), b2Vec2(-30.0f, 30.0f));
//				ground.CreateFixture(&sd);
//				
//				// Right vertical
//				shape.Set(b2Vec2(30.0f, -30.0f), b2Vec2(30.0f, 30.0f));
//				ground.CreateFixture(&sd);
//				
//				//Top horizontal
//				shape.Set(b2Vec2(-30.0f, 30.0f), b2Vec2(30.0f, 30.0f));
//				ground.CreateFixture(&sd);
//				
//				// Bottom horizontal
//				shape.Set(b2Vec2(-30.0f, -30.0f), b2Vec2(30.0f, -30.0f));
//				ground.CreateFixture(&sd);
//			} 

			initialize;
		}
	}

	override void initialize()
	{
		bodyColor = b2Color(1,1,1);
	}


	//Main step loop.
	override void Step(Settings* settings)
	{
		super.Step(settings);

		if (settings.useNN) time1 = glfwGetTime();

		import std.parallelism;
		import std.math; 
		float noise = settings.noise > 0 ? uniform(-settings.noise, settings.noise) : 0;

		foreach(i,ref n;parallel(networks))
		{
			if (settings.useNN)
			{
				assert(_creatures.length == networks.length);
				if (settings.paceMaker) n.inputs[0] += 0.5f + noise;
				n.tick(settings);

				if (settings.allowMovement) {
					if (n.outputs[0]) {
						_creatures[i].ApplyAngularImpulse(0.25f,true);
					}
					if (n.outputs[1]) {
						b2Vec2 f = _creatures[i].GetWorldVector(b2Vec2(0.0f, -10f));
						b2Vec2 p = _creatures[i].GetWorldPoint(b2Vec2(0.0f, 3.0f));
						_creatures[i].ApplyLinearImpulse(f,p,true);
					}
					if (n.outputs[2]) {
						_creatures[i].ApplyAngularImpulse(-0.25f,true);
					}
				}
			}
			else {
				if (settings.allowMovement) {
					if (uniform(0,10+(noise*5))) {
						_creatures[i].ApplyAngularImpulse(0.25f,true);
					}
					if (uniform(0,10+(noise*5))) {
						b2Vec2 f = _creatures[i].GetWorldVector(b2Vec2(0.0f, -10f));
						b2Vec2 p = _creatures[i].GetWorldPoint(b2Vec2(0.0f, 3.0f));
						_creatures[i].ApplyLinearImpulse(f,p,true);
					}
					if (uniform(0,10+(noise*5))) {
						_creatures[i].ApplyAngularImpulse(-0.25f,true);
					}
				}
			}
		}
		if (settings.useNN) {
			time2 = glfwGetTime();
			netTime = (time2 - time1) * 1000;
		}
	}

	static NeuralTest Create()
	{
		return new typeof(this);
	}
	
	static NetConf getNetConf()
	{
		return NetConf(4,[main.settings.hidden],3);
	}
}

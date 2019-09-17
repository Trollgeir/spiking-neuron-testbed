/*
 * Copyright (c) 2006-2007 Erin Catto http://www.box2d.org
 *
 * This software is provided 'as-is', without any express or implied
 * warranty.  In no event will the authors be held liable for any damages
 * arising from the use of this software.
 * Permission is granted to anyone to use this software for any purpose,
 * including commercial applications, and to alter it and redistribute it
 * freely, subject to the following restrictions:
 * 1. The origin of this software must not be misrepresented; you must not
 * claim that you wrote the original software. If you use this software
 * in a product, an acknowledgment in the product documentation would be
 * appreciated but is not required.
 * 2. Altered source versions must be plainly marked as such, and must not be
 * misrepresented as being the original software.
 * 3. This notice may not be removed or altered from any source distribution.
 */
module framework.test;

import core.stdc.stdlib;
import core.stdc.string;

import std.exception;
import std.stdio;
import std.string;

import deimos.glfw.glfw3;

import glad.gl.enums;
import glad.gl.ext;
import glad.gl.funcs;
import glad.gl.loader;
import glad.gl.types;

import glwtf.input;
import glwtf.window;

import dbox;

import imgui;

import network.network;
import framework.debug_draw;


enum DRAW_STRING_NEW_LINE = 16;

import main;

static float[] globalEyes()
{
	float[] a;
	float i = 0f;
	while(i <= 2f) {
		a ~= i;
		i += 0.01f;
	}
	//assert( a.length <= inputs);
	return a;
}

static float[] fullFrontEyes()
{
	float[] a;
	float i = 1f;
	while(i <= 2f) {
		a ~= i;
		i += 0.01f;
	}
	//assert( a.length <= inputs);
	return a;
}

//static float[] frontConeEyes()
//{
//	float[] a;
//	float i = 1.40f;
//	while(i <= 1.61f) {
//		a ~= i;
//		i += 0.05f;
//	}
//	return a;
//}

static float[] frontConeEyes(bool triRay)
{
	float origin = 1.5f;
	if(!triRay)
		return [origin];

	// 3 degrees
	float i = 0.0523599f;
	return [origin-i, origin, origin+i];
//	return [origin-i*4,origin-i, origin, origin+i,origin+i*4];
}


static float[] backConeEyes()
{
	float[] a;
	float i = 0.35f;
	while(i <= 0.66f) {
		a ~= i;
		i += 0.05f;
	}
//	assert( a.length <= inputs);
	return a;
//	return [0.5];
}



/// Test settings. Some can be controlled in the GUI.
struct Settings
{
	float32 hz = 60;
    float velocityIterations = 8;
    float positionIterations = 2;
	float speed = 0f;
	float noise = 0f;
    bool drawShapes = true;
    bool drawJoints = true;
    bool drawAABBs;
    bool drawContactPoints;
    bool drawContactNormals;
    bool drawContactImpulse;
    bool drawFrictionImpulse;
    bool drawCOMs;
	bool drawStats;
	bool drawProfile = true;
    bool enableWarmStarting = true;
    bool enableContinuous = true;
    bool enableSubStepping;
    bool enableSleep = true;
    bool enableVSync;
    bool pause;
    bool singleStep;
	bool chaseCam;
	bool foodCam;
	bool drawOutputs;
	bool drawActivity;
	bool drawSensor;
	bool infEnergy;
	bool drawTrace = true;

	//BGE settings
	bool newGen = false;
	size_t eliteSize = 10;
	bool proxFitness = true;
	bool pauseEvo = false;
	bool IF = false;
	uint mutProb = 20;
	size_t signalIdx = 30;
	float foodRadius = 0.5f;
	size_t ticksPerUpdate = 3;
	bool triRay = true;

	//Stress test settings 
	size_t creatureCount = 0;
	size_t hidden = 100;
	bool allowMovement = true;
	bool useNN = true;
	bool collision = true;
	bool paceMaker = true;
	bool recurrent = true;

	// Chemotaxi
	bool helperParams = false;
	bool motorClones = false;
	bool sensorClones = true;
	bool onNeuron = true;
	bool offNeuron = true;
	bool gradient = false;
	float antLength = 2.5f;
	bool bestNetwork = false;

	// Navigate
	size_t obstacleCount = 0;
	float reward = 7000f;
	float discount = 0.8f;
	bool clickMove = false;
	bool useEyes = true;
	bool drawRays = false;
}

alias TestCreateFcn = NeuralTest function();

struct TestEntry
{
    string name;
    TestCreateFcn createFcn;
	TestCreateFcn createCpuFcn;
	Spawn[] function(Settings*) createSpwn;
	NetConf function() getNetConf;
}

enum mode { cpu, render, user }

// This is called when a joint in the world is implicitly destroyed
// because an attached body is destroyed. This gives us a chance to
// nullify the mouse joint.
class DestructionListener : b2DestructionListener
{
    override void SayGoodbye(b2Fixture* fixture)
    {
        B2_NOT_USED(fixture);
    }

    override void SayGoodbye(b2Joint joint)
    {
        if (test.m_mouseJoint is joint)
        {
            test.m_mouseJoint = null;
        }
        else
        {
            test.JointDestroyed(joint);
        }
    }
	NeuralTest test;
}

enum k_maxContactPoints = 2048;

struct ContactPoint
{
    b2Fixture* fixtureA;
    b2Fixture* fixtureB;
    b2Vec2 normal;
    b2Vec2 position;
    b2PointState state;
    float32 normalImpulse = 0;
    float32 tangentImpulse = 0;
    float32 separation = 0;
}

class RayCastClosestCallback : b2RayCastCallback
{
	override float32 ReportFixture(b2Fixture* fixture, b2Vec2 point, b2Vec2 normal, float32 fraction)
	{
		b2Body* body_   = fixture.GetBody();
		void* userData = body_.GetUserData();

		if (userData)
		{
			int32 index = *cast(int32*)userData;

			if (index == 0)
			{
				// By returning -1, we instruct the calling code to ignore this fixture and
				// continue the ray-cast to the next fixture.
				return -1.0f;
			}
		}

		m_hit    = true;
		m_point  = point;
		m_normal = normal;
		m_body = body_;

		// By returning the current fraction, we instruct the calling code to clip the ray and
		// continue the ray-cast to the next fixture. WARNING: do not assume that fixtures
		// are reported in order. However, by clipping, we can always get the closest fixture.
		return fraction;
	}

	bool m_hit;
	b2Vec2 m_point;
	b2Vec2 m_normal;
	b2Body* m_body;
}

enum objType {circle,triangle,square};

struct Spawn
{
	b2Vec2 position;
	b2Color color;
	float size;
	bool food;
	bool isStatic = true;
	float alpha;
	float rotation;
	objType type;
}

class NeuralTest : b2ContactListener
{
	string name;
	import main : BGE;
	Settings* settings;
	size_t sleepCounter;
	RayCastClosestCallback cb;
	b2Body* m_body;
	b2Body* m_food;
	b2Body*[] m_obstacles;
	size_t foodCount;
	SNN network;
	Spawn[] spawns;
	float bestProx = 0;
	bool done;
	float energy;
	b2Vec2[] trace;
	b2Color bodyColor;
	b2CircleShape foodShape;
	double netTime;
	double netAvg;
	double netMax;
	double totalNet;

	void performTest()
	{
		initialize;
		while(!done) {
			Step(settings);
		}
	}

	void spawnPickup(Spawn spawn)
	{
		b2FixtureDef fd;
		if (!spawn.isStatic)
		{
			fd.restitution = 1;
			fd.friction = 0;
		}
		else
			fd.isSensor = true;

		foodShape.m_radius = settings.foodRadius;
		fd.shape = foodShape;

		{
			b2BodyDef bd;
			bd.type = (spawn.isStatic) ? b2_staticBody : b2_dynamicBody;

			bd.position.Set(spawn.position);
			m_food = m_world.CreateBody(&bd);

			m_food.CreateFixture(&fd);
		}
	}

	void spawnObstacles(Spawn[] spawns)
	{
		m_obstacles.length = spawns.length;
		foreach(i,spawn; spawns)
		{
			b2FixtureDef fd;

			switch (spawn.type)
			{
				case objType.circle:
					fd.shape = new b2CircleShape();
					fd.shape.m_radius = spawn.size;
					break;

				case objType.triangle:
//					b2Transform xf1;
//					xf1.q.Set(spawn.rotation);
//					xf1.p = xf1.q.GetXAxis();
					
					b2Vec2[3] vertices;
					vertices[0] = b2Vec2(-1.0f*spawn.size, 0.0f);
					vertices[1] = b2Vec2(1.0f*spawn.size, 0.0f);
					vertices[2] = b2Vec2(0.0f, 0.5f*spawn.size);
					
					b2PolygonShape poly1 = new b2PolygonShape();
					poly1.Set(vertices);

					fd.shape   = poly1;
					break;

				case objType.square:
				
					b2PolygonShape poly1 = new b2PolygonShape();
					poly1.SetAsBox(1f*spawn.size, 1f*spawn.size);

					fd.shape = poly1;
					break;



				default:
					fd.shape = new b2CircleShape();
					fd.shape.m_radius = spawn.size;
					break;
			}



//			fd.friction = 1000;
			fd.filter.groupIndex = -2;


			{
				b2BodyDef bd;
				bd.type = (spawn.isStatic) ? b2_staticBody : b2_dynamicBody;
				bd.position.Set(spawn.position);
				m_obstacles[i] = m_world.CreateBody(&bd);
				m_obstacles[i].CreateFixture(&fd);
				m_obstacles[i].SetTransform(spawn.position,spawn.rotation);
			}
		}
	}


    this(bool creatureSensor = false)
    {
		totalNet = 0;
		netMax = 0;
		netAvg = 0;
		foodShape = new b2CircleShape();
		cb = new RayCastClosestCallback();
        b2Vec2 gravity;
        gravity.Set(0.0f, 0.0f);
        m_world  = b2World(gravity);
        m_textLine   = 30;
        m_mouseJoint = null;
        m_pointCount = 0;

        m_destructionListener = new DestructionListener();

        m_destructionListener.test = this;
        m_world.SetDestructionListener(m_destructionListener);
        m_world.SetContactListener(this);

        m_stepCount = 0;

        b2BodyDef bodyDef;
        m_groundBody = m_world.CreateBody(&bodyDef);

        memset(&m_maxProfile, 0, b2Profile.sizeof);
        memset(&m_totalProfile, 0, b2Profile.sizeof);

		const float32 k_restitution = 0.4f;


		//Creature shape
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
			sd1.friction = 1;
			sd1.filter.groupIndex = -1;

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
			sd1.friction = sd1.friction;
			sd2.filter.groupIndex = sd1.filter.groupIndex;

			b2BodyDef bd;
			bd.type = b2_dynamicBody;
			bd.angularDamping = 10.0f;
			bd.linearDamping  = 10.0f;


			b2Vec2 centerPos;
			bd.position.Set(centerPos);
			bd.angle      = b2_pi;
			bd.allowSleep = true;


//			b2FixtureDef fd;
//			auto temp = new b2CircleShape;
//			temp.m_radius = 0.5;
//			fd.shape = temp;
//			fd.density = 2.0f;
			if(creatureSensor)
			{
				sd1.isSensor = true;
				sd2.isSensor = true;
			}
			m_body = m_world.CreateBody(&bd);
			m_body.CreateFixture(&sd1);
			m_body.CreateFixture(&sd2);
//			m_body.CreateFixture(&fd);
		}
    }

	NeuralTest restart()
	{
		assert(0, "We forgot to override!");
	}

	abstract void initialize();


	static Spawn[] createSpawns(Settings* set)
	{
		return null;
	}


    // Callbacks for derived classes.
    override void BeginContact(b2Contact contact)
    {
        B2_NOT_USED(contact);
    }

    override void EndContact(b2Contact contact)
    {
        B2_NOT_USED(contact);
    }

    override void PreSolve(b2Contact contact, const(b2Manifold)* oldManifold)
    {
        const(b2Manifold)* manifold = contact.GetManifold();

        if (manifold.pointCount == 0)
        {
            return;
        }

        b2Fixture* fixtureA = contact.GetFixtureA();
        b2Fixture* fixtureB = contact.GetFixtureB();

        b2PointState[b2_maxManifoldPoints] state1, state2;
        b2GetPointStates(state1, state2, oldManifold, manifold);

        b2WorldManifold worldManifold;
        contact.GetWorldManifold(&worldManifold);

        for (int32 i = 0; i < manifold.pointCount && m_pointCount < k_maxContactPoints; ++i)
        {
            ContactPoint* cp = &m_points[m_pointCount];
            cp.fixtureA       = fixtureA;
            cp.fixtureB       = fixtureB;
            cp.position       = worldManifold.points[i];
            cp.normal         = worldManifold.normal;
            cp.state          = state2[i];
            cp.normalImpulse  = manifold.points[i].normalImpulse;
            cp.tangentImpulse = manifold.points[i].tangentImpulse;
            cp.separation     = worldManifold.separations[i];
            ++m_pointCount;
        }
    }

    override void PostSolve(b2Contact contact, const(b2ContactImpulse)* impulse)
    {
        B2_NOT_USED(contact);
        B2_NOT_USED(impulse);
    }

    void DrawTitle(string str)
    {
        g_debugDraw.DrawString(5, DRAW_STRING_NEW_LINE, str);
        m_textLine = 3 * DRAW_STRING_NEW_LINE;
    }

    void MouseDown(b2Vec2 p)
    {
        m_mouseWorld = p;

        if (m_mouseJoint !is null)
        {
            return;
        }

        // Make a small box.
        b2AABB aabb;
        b2Vec2 d;
        d.Set(0.001f, 0.001f);
        aabb.lowerBound = p - d;
        aabb.upperBound = p + d;

        // Query the world for overlapping shapes.
        QueryCallback callback = new QueryCallback(p);
        m_world.QueryAABB(callback, aabb);

        if (callback.m_fixture)
        {
            b2Body* body_ = callback.m_fixture.GetBody();
            b2MouseJointDef md = new b2MouseJointDef;
            md.bodyA     = m_groundBody;
            md.bodyB     = body_;
            md.target    = p;
            md.maxForce  = 1000.0f * body_.GetMass();
            m_mouseJoint = cast(b2MouseJoint)m_world.CreateJoint(md);
            body_.SetAwake(true);
        }
    }


    void ShiftMouseDown(b2Vec2 p)
    {
        m_mouseWorld = p;

        if (m_mouseJoint !is null)
        {
            return;
        }
    }

    void MouseUp(b2Vec2 p)
    {
        if (m_mouseJoint)
        {
            m_world.DestroyJoint(m_mouseJoint);
            m_mouseJoint = null;
        }
    }

    void MouseMove(b2Vec2 p)
    {
        m_mouseWorld = p;

        if (m_mouseJoint)
        {
            m_mouseJoint.SetTarget(p);
        }
    }


    void Draw(Settings* settings)
    {
		import framework.render : testSelection;
		import tests.test_entries : g_testEntries;
		auto test = g_testEntries[testSelection];
		DrawTitle(test.name);

		if (test.name != "StressTest") {
			g_debugDraw.DrawString(5, m_textLine, format("Energy: %s", energy));
			m_textLine += DRAW_STRING_NEW_LINE;
			g_debugDraw.DrawString(5, m_textLine, format("Best proximity : %s", bestProx));
			m_textLine += DRAW_STRING_NEW_LINE;
			g_debugDraw.DrawString(5, m_textLine, format("Best fitness : %s", BGE.bestFitness));
			m_textLine += DRAW_STRING_NEW_LINE;

			NetConf arch = test.getNetConf();
			g_debugDraw.DrawString(5, m_textLine, format("Input  Neurons: %s", arch.inputs));
			m_textLine += DRAW_STRING_NEW_LINE;
			g_debugDraw.DrawString(5, m_textLine, format("Hidden Neurons: %s", arch.hidden));
			m_textLine += DRAW_STRING_NEW_LINE;
			g_debugDraw.DrawString(5, m_textLine, format("Output Neurons: %s", arch.outputs));
			m_textLine += DRAW_STRING_NEW_LINE;
		}
		else
		{
			auto p = m_world.GetProfile();
			
			b2Profile aveProfile;
			memset(&aveProfile, 0, b2Profile.sizeof);
			
			if (m_stepCount > 0)
			{
				float32 scale = 1.0f / m_stepCount;
				aveProfile.step          = scale * m_totalProfile.step;
				aveProfile.collide       = scale * m_totalProfile.collide;
				aveProfile.solve         = scale * m_totalProfile.solve;
				aveProfile.solveInit     = scale * m_totalProfile.solveInit;
				aveProfile.solveVelocity = scale * m_totalProfile.solveVelocity;
				aveProfile.solvePosition = scale * m_totalProfile.solvePosition;
				aveProfile.solveTOI      = scale * m_totalProfile.solveTOI;
				aveProfile.broadphase    = scale * m_totalProfile.broadphase;
				netAvg					 = scale * totalNet;
			}
			
			{
				m_maxProfile.step          = b2Max(m_maxProfile.step, p.step);
				m_maxProfile.collide       = b2Max(m_maxProfile.collide, p.collide);
				m_maxProfile.solve         = b2Max(m_maxProfile.solve, p.solve);
				m_maxProfile.solveInit     = b2Max(m_maxProfile.solveInit, p.solveInit);
				m_maxProfile.solveVelocity = b2Max(m_maxProfile.solveVelocity, p.solveVelocity);
				m_maxProfile.solvePosition = b2Max(m_maxProfile.solvePosition, p.solvePosition);
				m_maxProfile.solveTOI      = b2Max(m_maxProfile.solveTOI, p.solveTOI);
				m_maxProfile.broadphase    = b2Max(m_maxProfile.broadphase, p.broadphase);
				if (netTime > netMax) netMax = netTime;
				
				m_totalProfile.step          += p.step;
				m_totalProfile.collide       += p.collide;
				m_totalProfile.solve         += p.solve;
				m_totalProfile.solveInit     += p.solveInit;
				m_totalProfile.solveVelocity += p.solveVelocity;
				m_totalProfile.solvePosition += p.solvePosition;
				m_totalProfile.solveTOI      += p.solveTOI;
				m_totalProfile.broadphase    += p.broadphase;
				totalNet					 += netTime;
			}
			
			
			g_debugDraw.DrawString(5, m_textLine, format("collide [ave] (max) = %5.2f [%6.2f] (%6.2f)", p.collide, aveProfile.collide, m_maxProfile.collide));
			m_textLine += DRAW_STRING_NEW_LINE;
			g_debugDraw.DrawString(5, m_textLine, format("solve [ave] (max) = %5.2f [%6.2f] (%6.2f)", p.solve, aveProfile.solve, m_maxProfile.solve));
			m_textLine += DRAW_STRING_NEW_LINE;
			g_debugDraw.DrawString(5, m_textLine, format("solve init [ave] (max) = %5.2f [%6.2f] (%6.2f)", p.solveInit, aveProfile.solveInit, m_maxProfile.solveInit));
			m_textLine += DRAW_STRING_NEW_LINE;
			g_debugDraw.DrawString(5, m_textLine, format("solve velocity [ave] (max) = %5.2f [%6.2f] (%6.2f)", p.solveVelocity, aveProfile.solveVelocity, m_maxProfile.solveVelocity));
			m_textLine += DRAW_STRING_NEW_LINE;
			g_debugDraw.DrawString(5, m_textLine, format("solve position [ave] (max) = %5.2f [%6.2f] (%6.2f)", p.solvePosition, aveProfile.solvePosition, m_maxProfile.solvePosition));
			m_textLine += DRAW_STRING_NEW_LINE;
			g_debugDraw.DrawString(5, m_textLine, format("solveTOI [ave] (max) = %5.2f [%6.2f] (%6.2f)", p.solveTOI, aveProfile.solveTOI, m_maxProfile.solveTOI));
			m_textLine += DRAW_STRING_NEW_LINE;
			g_debugDraw.DrawString(5, m_textLine, format("broad-phase [ave] (max) = %5.2f [%6.2f] (%6.2f)", p.broadphase, aveProfile.broadphase, m_maxProfile.broadphase));
			m_textLine += DRAW_STRING_NEW_LINE;
			g_debugDraw.DrawString(5,m_textLine,"-----------------------------");
			m_textLine += DRAW_STRING_NEW_LINE;
			g_debugDraw.DrawString(5, m_textLine, format("physics step [ave] (max) = %5.2f [%6.2f] (%6.2f)", p.step, aveProfile.step, m_maxProfile.step));
			m_textLine += DRAW_STRING_NEW_LINE;
			g_debugDraw.DrawString(5, m_textLine, format("neural networks [ave] (max) = %5.2f [%6.2f] (%6.2f)", netTime, netAvg, netMax));
			m_textLine += DRAW_STRING_NEW_LINE;
			g_debugDraw.DrawString(5, m_textLine, format("render = %5.2f",framework.render.dur));
			m_textLine += DRAW_STRING_NEW_LINE;
		}

        uint32 flags = 0;
        flags += settings.drawShapes * b2Draw.e_shapeBit;
        flags += settings.drawJoints * b2Draw.e_jointBit;
        flags += settings.drawAABBs * b2Draw.e_aabbBit;
        flags += settings.drawCOMs * b2Draw.e_centerOfMassBit;
        g_debugDraw.SetFlags(flags);

        glfwSwapInterval(settings.enableVSync ? 1 : 0);

        m_pointCount = 0;

        m_world.DrawDebugData();
        g_debugDraw.Flush();

        if (settings.drawStats)
        {
            int32 bodyCount    = m_world.GetBodyCount();
            int32 contactCount = m_world.GetContactCount();
            int32 jointCount   = m_world.GetJointCount();
            g_debugDraw.DrawString(5, m_textLine, format("bodies/contacts/joints = %d/%d/%d", bodyCount, contactCount, jointCount));
            m_textLine += DRAW_STRING_NEW_LINE;

            int32 proxyCount = m_world.GetProxyCount();
            int32 height     = m_world.GetTreeHeight();
            int32 balance    = m_world.GetTreeBalance();
            float32 quality  = m_world.GetTreeQuality();
            g_debugDraw.DrawString(5, m_textLine, format("proxies/height/balance/quality = %d/%d/%d/%g", proxyCount, height, balance, quality));
            m_textLine += DRAW_STRING_NEW_LINE;

        }

        if (m_mouseJoint)
        {
            b2Vec2 p1 = m_mouseJoint.GetAnchorB();
            b2Vec2 p2 = m_mouseJoint.GetTarget();

            b2Color c;
            c.Set(0.0f, 1.0f, 0.0f);
            g_debugDraw.DrawPoint(p1, 4.0f, c);
            g_debugDraw.DrawPoint(p2, 4.0f, c);

            c.Set(0.8f, 0.8f, 0.8f);
            g_debugDraw.DrawSegment(p1, p2, c);
        }


        if (settings.drawContactPoints)
        {
            const float32 k_impulseScale = 0.1f;
            const float32 k_axisScale    = 0.3f;

            for (int32 i = 0; i < m_pointCount; ++i)
            {
                ContactPoint* point = &m_points[i];

                if (point.state == b2_addState)
                {
                    // Add
                    g_debugDraw.DrawPoint(point.position, 10.0f, b2Color(0.3f, 0.95f, 0.3f));
                }
                else if (point.state == b2_persistState)
                {
                    // Persist
                    g_debugDraw.DrawPoint(point.position, 5.0f, b2Color(0.3f, 0.3f, 0.95f));
                }

                if (settings.drawContactNormals == 1)
                {
                    b2Vec2 p1 = point.position;
                    b2Vec2 p2 = p1 + k_axisScale * point.normal;
                    g_debugDraw.DrawSegment(p1, p2, b2Color(0.9f, 0.9f, 0.9f));
                }
                else if (settings.drawContactImpulse == 1)
                {
                    b2Vec2 p1 = point.position;
                    b2Vec2 p2 = p1 + k_impulseScale * point.normalImpulse * point.normal;
                    g_debugDraw.DrawSegment(p1, p2, b2Color(0.9f, 0.9f, 0.3f));
                }

                if (settings.drawFrictionImpulse == 1)
                {
                    b2Vec2 tangent = b2Cross(point.normal, 1.0f);
                    b2Vec2 p1      = point.position;
                    b2Vec2 p2      = p1 + k_impulseScale * point.tangentImpulse * tangent;
                    g_debugDraw.DrawSegment(p1, p2, b2Color(0.9f, 0.9f, 0.3f));
                }
            }
        }
    }

    void Step(Settings* settings)
    {
		float32 timeStep = settings.hz > 0.0f ? 1.0f / settings.hz : cast(float32)0.0f;


        //uint32 flags = 0;
        //flags += settings.drawShapes * b2Draw.e_shapeBit;
        //flags += settings.drawJoints * b2Draw.e_jointBit;
        //flags += settings.drawAABBs * b2Draw.e_aabbBit;
        //flags += settings.drawCOMs * b2Draw.e_centerOfMassBit;
        //g_debugDraw.SetFlags(flags);

        //glfwSwapInterval(settings.enableVSync ? 1 : 0);

//        m_world.SetAllowSleeping(settings.enableSleep);
//        m_world.SetWarmStarting(settings.enableWarmStarting);
//        m_world.SetContinuousPhysics(settings.enableContinuous);
//        m_world.SetSubStepping(settings.enableSubStepping);

        //m_pointCount = 0;
        m_world.Step(timeStep, cast(int)settings.velocityIterations, cast(int)settings.positionIterations);

//        m_world.DrawDebugData();
//        g_debugDraw.Flush();

//        if (timeStep > 0.0f)
//        {
            ++m_stepCount;
//        }

    }

    void ShiftOrigin(b2Vec2 newOrigin)
    {
        m_world.ShiftOrigin(newOrigin);
    }

    void Keyboard(int key)
    {
        B2_NOT_USED(key);
    }

    void KeyboardUp(int key)
    {
        B2_NOT_USED(key);
    }


    // Let derived tests know that a joint was destroyed.
    void JointDestroyed(b2Joint joint)
    {
        B2_NOT_USED(joint);
    }

protected:
    b2Body* m_groundBody;
    b2AABB  m_worldAABB;
	ContactPoint[k_maxContactPoints] m_points;
    int32 m_pointCount;
    DestructionListener m_destructionListener;
    int32 m_textLine;
    b2World m_world;
    b2MouseJoint m_mouseJoint;
    b2Vec2 m_mouseWorld;
    int32  m_stepCount;

    b2Profile m_maxProfile;
    b2Profile m_totalProfile;
}

class QueryCallback : b2QueryCallback
{
public:
    this(b2Vec2 point)
    {
        m_point   = point;
        m_fixture = null;
    }

    override bool ReportFixture(b2Fixture* fixture)
    {
        b2Body* body_ = fixture.GetBody();

        if (body_.GetType() == b2_dynamicBody)
        {
            bool inside = fixture.TestPoint(m_point);

            if (inside)
            {
                m_fixture = fixture;

                // We are done, terminate the query.
                return false;
            }
        }

        // Continue the query.
        return true;
    }

    b2Vec2 m_point;
    b2Fixture* m_fixture;
}

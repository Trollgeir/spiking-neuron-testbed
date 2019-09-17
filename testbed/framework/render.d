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
module framework.render;

// initial test
enum entryTestName = "";

import std.algorithm;
import std.exception;
import std.file;
import std.path;
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
import imgui.engine;

import tests.test_entries;

import framework.debug_draw;
import framework.test;
import framework.window;


enum RED    = RGBA(255,   0,   0, 255);
enum GREEN  = RGBA(  0, 255,   0, 255);
enum BLUE   = RGBA(  0,   0, 255, 255);
enum WHITE  = RGBA(255, 255, 255, 255);
enum BLACK  = RGBA(0, 0, 0, 255);
enum SILVER = RGBA(220, 220, 220, 255);

//
struct UIState
{
	bool showMenu;
	int scroll;
	int scrollarea1;
	bool mouseOverMenu;
	bool chooseTest;
}

GLFWwindow* mainWindow;
UIState ui;

sizediff_t testIndex;
shared sizediff_t testSelection;
TestEntry* entry;
NeuralTest test;
bool moveCamera;
b2Vec2 lastp;

//
void sCreateUI()
{
	ui.showMenu      = true;
	ui.scroll        = 0;
	ui.scrollarea1   = 0;
	ui.chooseTest    = false;
	ui.mouseOverMenu = false;
	
	string fontPath = thisExePath().dirName().buildPath("DroidSans.ttf");
	
	if (imguiInit(fontPath) == false)
	{
		fprintf(stderr.getFP(), "Could not init GUI renderer.\n");
		assert(false);
	}
}

//void choosePrevTest()
//{
//	--testSelection;
//	if (testSelection < 0)
//		testSelection = g_testEntries.length - 1;
//}
//
//void chooseNextTest()
//{
//	++testSelection;
//	if (testSelection == g_testEntries.length)
//		testSelection = 0;
//}

//
extern(C) void sResizeWindow(GLFWwindow*, int width, int height)
{
	g_camera.m_width  = width;
	g_camera.m_height = height;
}

//
extern(C) void sKeyCallback(GLFWwindow*, int key, int scancode, int action, int mods)
{
	if (action == GLFW_PRESS || action == GLFW_REPEAT)
	{
		switch (key)
		{
			case GLFW_KEY_ESCAPE:
				
				// Quit
				glfwSetWindowShouldClose(mainWindow, GL_TRUE);
				break;
				
			case GLFW_KEY_LEFT:
				
				// Pan left
				if (mods == GLFW_MOD_CONTROL)
				{
					b2Vec2 newOrigin = b2Vec2(2.0f, 0.0f);
					test.ShiftOrigin(newOrigin);
				}
				else
				{
					g_camera.m_center.x -= 0.5f;
				}
				break;
				
			case GLFW_KEY_RIGHT:
				
				// Pan right
				if (mods == GLFW_MOD_CONTROL)
				{
					b2Vec2 newOrigin = b2Vec2(-2.0f, 0.0f);
					test.ShiftOrigin(newOrigin);
				}
				else
				{
					g_camera.m_center.x += 0.5f;
				}
				break;
				
			case GLFW_KEY_DOWN:
				
				// Pan down
				if (mods == GLFW_MOD_CONTROL)
				{
					b2Vec2 newOrigin = b2Vec2(0.0f, 2.0f);
					test.ShiftOrigin(newOrigin);
				}
				else
				{
					g_camera.m_center.y -= 0.5f;
				}
				break;
				
			case GLFW_KEY_UP:
				
				// Pan up
				if (mods == GLFW_MOD_CONTROL)
				{
					b2Vec2 newOrigin = b2Vec2(0.0f, -2.0f);
					test.ShiftOrigin(newOrigin);
				}
				else
				{
					g_camera.m_center.y += 0.5f;
				}
				break;
				
			case GLFW_KEY_HOME:
				
				// Reset view
				g_camera.m_zoom = 1.0f;
				g_camera.m_center.Set(0.0f, 20.0f);
				break;
				
			case GLFW_KEY_Z:
				
				// Zoom out
				g_camera.m_zoom = b2Min(1.1f * g_camera.m_zoom, 20.0f);
				break;
				
			case GLFW_KEY_X:
				
				// Zoom in
				g_camera.m_zoom = b2Max(0.9f * g_camera.m_zoom, 0.02f);
				break;
				
			case GLFW_KEY_SPACE:
				
				// Reset test
				
				sRestart;
				break;
				
			case GLFW_KEY_P:
				
				// Pause
				settings.pause = !settings.pause;
				break;
				
			case GLFW_KEY_LEFT_BRACKET:
//				choosePrevTest();
				break;
				
			case GLFW_KEY_RIGHT_BRACKET:
//				chooseNextTest();
				break;
				
			case GLFW_KEY_TAB:
				ui.showMenu = !ui.showMenu;
				break;
				
			default:
				
				if (test)
				{
					test.Keyboard(key);
				}
		}
	}
	else if (action == GLFW_RELEASE)
	{
		test.KeyboardUp(key);
	}
	
	// else GLFW_REPEAT
}

//
extern(C) void sMouseButton(GLFWwindow*, int32 button, int32 action, int32 mods)
{
	double xd, yd;
	glfwGetCursorPos(mainWindow, &xd, &yd);
	b2Vec2 ps = b2Vec2(cast(float32)xd, cast(float32)yd);
	
	// Use the mouse to move things around.
	if (button == GLFW_MOUSE_BUTTON_1)
	{
		// <##>
		// ps.Set(0, 0);
		b2Vec2 pw = g_camera.ConvertScreenToWorld(ps);
		
		if (action == GLFW_PRESS)
		{
			if (mods == GLFW_MOD_SHIFT)
			{
				test.ShiftMouseDown(pw);
			}
			else
			{
				test.MouseDown(pw);
			}
		}
		
		if (action == GLFW_RELEASE)
		{
			test.MouseUp(pw);
		}
	}
	else
		if (button == GLFW_MOUSE_BUTTON_2 || button == GLFW_MOUSE_BUTTON_3)
	{
		if (action == GLFW_PRESS)
		{
			lastp = g_camera.ConvertScreenToWorld(ps);
			moveCamera = true;
		}
		
		if (action == GLFW_RELEASE)
		{
			moveCamera = false;
		}
	}
}

//
extern(C) void sMouseMotion(GLFWwindow*, double xd, double yd)
{
	b2Vec2 ps = b2Vec2(cast(float)xd, cast(float)yd);
	
	b2Vec2 pw = g_camera.ConvertScreenToWorld(ps);
	test.MouseMove(pw);
	
	if (moveCamera)
	{
		b2Vec2 diff = pw - lastp;
		g_camera.m_center.x -= diff.x;
		g_camera.m_center.y -= diff.y;
		lastp = g_camera.ConvertScreenToWorld(ps);
	}
}

//
extern(C) void sScrollCallback(GLFWwindow*, double, double dy)
{
	if (ui.mouseOverMenu)
	{
		ui.scroll = -cast(int)dy;
	}
	else
	{
		if (dy > 0)
		{
			g_camera.m_zoom /= 1.1f;
		}
		else
		{
			g_camera.m_zoom *= 1.1f;
		}
	}
}

//
void sRestart()
{
//	entry = &g_testEntries[testIndex];
	import core.memory;
	GC.collect;
	test  = entry.createFcn();
	test.settings = &settings;
	test.totalNet = 0;
	test.netAvg = 0;
}

void printNetwork()
{
	if(entry.name == "StressTest") return;
	import std.file;
	File networkFile = File("bestNetwork.txt","w");

	size_t nIdx;
	foreach(i,layerCount; test.network._layers)
	{
		networkFile.writeln();
		networkFile.writeln("// L",i+1,":");
		networkFile.writeln();
		foreach(j; nIdx .. nIdx+layerCount)
		{
			networkFile.writeln("// -------------------------------");
			networkFile.writeln(test.network.neuronInfo(j));
		}
		nIdx += layerCount;
	}
	networkFile.writeln("network.reflex = ",test.network.reflex,";");
	networkFile.close();
}

double dur;
double LastTime = 0;
int Accumulator = 0;
int lastSpd = 0;
import std.datetime;
StopWatch drawTime;


void sSimulate()
{

	if (testSelection != testIndex)
	{
		BGE.sampleReady = false;
//		while (BGE.sampleReady == false)
//		{
//			import core.thread;
//			Thread.sleep(10.msecs);
//		}
		testIndex = testSelection;
		entry = &g_testEntries[testIndex];
		test  = entry.createFcn();
		test.settings = &settings;
		g_camera.m_zoom = 1.0f;
		g_camera.m_center.Set(0.0f, 20.0f);
	}

	if (test.done) {
		sRestart;
	}

//	double time = glfwGetTime();
//	double dt;
//	dt = time - LastTime;
//	else {
//		dt = settings.speed;
//	}
	
//	    if (dt > 0.2)
//	        dt = 0.2;
//	
//	double fixed_dt = 0.02;
	drawTime.stop;
	test.Step(&settings);

	import core.thread;
	int spd = cast(int)settings.speed;
	if (spd != 0) {
		Thread.sleep(spd.msecs);
	}

//	if (spd == 0) {
//		test.Step(&settings);
//	}
//	else {
//		if (spd != lastSpd)
//		{
//			lastSpd = spd;
//			Accumulator = spd;
//		}
//		--Accumulator;
//		if (Accumulator == 0) {
//			test.Step(&settings);
//			Accumulator += spd;
//		}
//	}
//	else {
//		for (Accumulator += dt; Accumulator > fixed_dt; Accumulator -= fixed_dt)
//		{
//			test.Step(&settings);
//		}
//	}
	drawTime.start;
	test.Draw(&settings);
}

enum menuType {world, evol, visuals, network, sensors, empty}

menuType selectedMenu = menuType.empty;

//
void sInterface()
{
	int menuWidth = 200;
	ui.mouseOverMenu = false;

	if (ui.showMenu)
	{
		bool over = imguiBeginScrollArea("Test Controls", g_camera.m_width - menuWidth - 10, 10, menuWidth, g_camera.m_height - 20, &ui.scrollarea1);
		
		if (over)
			ui.mouseOverMenu = true;
		
		imguiSeparatorLine();
		
		imguiLabel("Active Test:");
		
		if (imguiButton(entry.name))
		{
			ui.chooseTest = !ui.chooseTest;
		}
		imguiSeparatorLine();

//		imguiSeparatorLine();
//		
//		if (imguiButton("Next test"))
//			chooseNextTest();

		if (selectedMenu == menuType.world)
		{
			if (imguiButton("World / Creature"))
			{
				selectedMenu = menuType.empty;
			}
			else 
				selectedMenu = menuType.world;

			imguiIndent();

			imguiSlider("Hz", &settings.hz, 1f, 1000f, 1f);
			imguiSlider("Food size", &settings.foodRadius, 0.01f, 20f, 0.01f);
			imguiSlider("Sensor noise", &settings.noise, 0f, 1f, 0.01f);
			imguiCheck("Infinite energy",&settings.infEnergy);
			if (entry.name == "Chemotaxi - Mono" || entry.name == "Chemotaxi - Experiment" || entry.name == "Pathing")
				imguiCheck("Gaussian concentration",&settings.gradient);
			if (entry.name == "TED" || entry.name == "Spotter")
				imguiCheck("Triple Rays",&settings.triRay);

			if (entry.name == "Chemotaxi - Mono" || entry.name == "Chemotaxi - Stereo" || entry.name == "Chemotaxi - Experiment" || entry.name == "Pathing")
			{
				imguiLabel("Sensor neuron(s)");
				imguiCheck("ON neuron",&settings.onNeuron);
				imguiCheck("OFF neuron",&settings.offNeuron);
				imguiSlider("Antenna length", &settings.antLength, 0f, 10f, 0.01f);
				
				if (entry.name == "Chemotaxi - Experiment" || entry.name == "Pathing")
				{
					{
						float temp = settings.creatureCount;
						imguiSlider("Creature Count ", &temp, 1f, 1000f, 10f);
						settings.creatureCount = to!size_t(temp);
					}
					imguiCheck("Collision (req. restart)",&settings.collision);
				}
			}

			if (entry.name == "Pathing")
			{
				{
					float temp = settings.obstacleCount;
					imguiSlider("Obstacle count ", &temp, 0f, 15f, 1f);
					settings.obstacleCount = to!size_t(temp);
				}

				imguiCheck("Click to move", &settings.clickMove);
				imguiCheck("Use eyes", &settings.useEyes);
				
				if(settings.clickMove)
				{
					settings.pauseEvo = true;
					settings.infEnergy = true;
					settings.gradient = true;
				}
			}
			imguiUnindent();
		}
		else
		{
			if (imguiButton("World / Creature")) 
			{ 
				selectedMenu = menuType.world; 
			}
		}


		imguiSeparatorLine();

		import tests.test_entries;
		if (entry.name != "StressTest")
		{
			if (selectedMenu == menuType.evol)
			{
				if (imguiButton("Evolution"))
				{
					selectedMenu = menuType.empty;
				}
				else 
					selectedMenu = menuType.evol;
				
				imguiIndent();
				if (imguiButton("New Generation"))
				{
					BGE.sampleReady = false;
					settings.pauseEvo = false;
				}
				
				imguiCheck("Pause Evolution",&settings.pauseEvo);
				
				{
					float temp = BGE.settings.eliteSize;
					imguiSlider("Elite size", &temp, 0f, 100, 1f);
					BGE.settings.eliteSize = to!size_t(temp);
				}
				
				{
					float temp = BGE.settings.mutProb;
					imguiSlider("Mutation chance     1 / ", &temp, 1f, 500f, 1f);
					BGE.settings.mutProb = to!size_t(temp);
				}
				imguiCheck("Prox Fitness",&settings.proxFitness);
				imguiSlider("Reward ", &settings.reward, 1f, 30000f, 10f);
				imguiSlider("Discount ", &settings.discount, 0.01f, 1f, 0.01f);
				imguiUnindent();																								
			}
			else
			{
				if (imguiButton("Evolution")) 
				{ 
					selectedMenu = menuType.evol; 
				}
			}
																																																												
			imguiSeparatorLine();

			if (selectedMenu == menuType.visuals)
			{
				if(imguiButton("Visuals"))
				{
					selectedMenu = menuType.empty;																																																	
				}
				else 
					selectedMenu = menuType.visuals;

				imguiIndent();

				imguiCheck("Draw trace",&settings.drawTrace);
				//			imguiCheck("Draw outputs",&settings.drawOutputs);
				imguiCheck("Draw sensors",&settings.drawSensor);
				imguiCheck("Draw rays",&settings.drawRays);
				imguiSlider("Slowmo", &settings.speed, 0f, 200f, 1f);
				
				string camera;
				
				if (settings.chaseCam == true)
					camera = "Camera: creature";
				else if (settings.foodCam == true)
					camera = "Camera: food";
				else 
					camera ="Camera: free";
				
				if (imguiButton(camera))
				{
					if (settings.chaseCam)
					{
						settings.chaseCam = false;
						settings.foodCam = true;
					}
					else if (settings.foodCam)
					{
						settings.chaseCam = false;
						settings.foodCam = false;
					}
					else
					{
						settings.chaseCam = true;
						settings.foodCam = false;
					}
				}
				imguiUnindent();
			}
			else
			{
				if (imguiButton("Visuals")) 
				{ 
					selectedMenu = menuType.visuals; 
				}
			}

			imguiSeparatorLine();	
		}
		
		if (selectedMenu == menuType.network)
		{
			if (imguiButton("Network"))
			{
				selectedMenu = menuType.empty;
			}
			else 
				selectedMenu = menuType.network;
			
			imguiIndent();
			if (imguiButton("Save network"))
				printNetwork();
			{
				float temp = settings.ticksPerUpdate;
				imguiSlider("Network Updates", &temp, 1f, 20f, 1f);
				settings.ticksPerUpdate = to!size_t(temp);
			}
			imguiCheck("Recurrent neurons",&settings.recurrent);
			imguiCheck("Static threshold",&settings.IF);
			imguiCheck("Pacemaker",&settings.paceMaker);
			imguiCheck("Motor neuron clones",&settings.motorClones);
			imguiCheck("Sensor neuron clones",&settings.sensorClones);
			imguiCheck("Best Network",&settings.bestNetwork);
			imguiCheck("Helper params",&settings.helperParams);
			imguiUnindent();
		}
		else
		{
			if (imguiButton("Network")) 
			{ 
				selectedMenu = menuType.network; 
			}
		}
		imguiSeparatorLine();

//		imguiSlider("Vel Iters", &settings.velocityIterations, 0, 50, 1);
//		imguiSlider("Pos Iters", &settings.positionIterations, 0, 50, 1);
		//imguiCheck("Fixed Speed", &settings.fixedSpeed);
		//imguiCheck("Precise Rendering", &settings.preciseRender);


		if (entry.name == "Junction")
		{
			imguiLabel("Junction test parameters");
			float temp = settings.signalIdx;
			imguiSlider("Signal location ", &temp, 0f, 39f, 1f);
			settings.signalIdx = to!size_t(temp);
			imguiSeparatorLine();
		}


		if (entry.name == "StressTest")
		{
			imguiLabel("Stress Test parameters");
			if (imguiButton("Restart"))
				sRestart;
			{
				float temp = settings.creatureCount;
				imguiSlider("Creature Count ", &temp, 1f, 10000f, 100f);
				settings.creatureCount = to!size_t(temp);
			}
			{
				float temp = settings.hidden;
				imguiSlider("Hidden neurons ", &temp, 10f, 2000f, 10f);
				settings.hidden = to!size_t(temp);
			}
			imguiCheck("Allow Movement",&settings.allowMovement);
			imguiCheck("Use Neural Network",&settings.useNN);
			imguiCheck("Collision (req. restart)",&settings.collision);
			imguiSeparatorLine();
		}
//		
//		imguiCheck("Statistics", &settings.drawStats);
//		
//		imguiCheck("Profile", &settings.drawProfile);
		
//		if (imguiButton(settings.pause ? "Resume" : "Pause"))
//			settings.pause = !settings.pause;

		
//		if (imguiButton("Single Step"))
//		{
//			if (!settings.pause)
//				settings.pause = true;
//			
//			settings.singleStep = !settings.singleStep;
//		}
		
//		if (imguiButton("Restart"))
//			sRestart();
		
		if (imguiButton("Quit"))
			glfwSetWindowShouldClose(mainWindow, GL_TRUE);
		
		imguiEndScrollArea();
	}
	
	int testMenuWidth = 200;
	
	if (ui.chooseTest)
	{
		static int testScroll = 0;
		bool over = imguiBeginScrollArea("Choose Test", g_camera.m_width - menuWidth - testMenuWidth - 20, 10, testMenuWidth, g_camera.m_height - 20, &testScroll);
		
		if (over)
			ui.mouseOverMenu = true;
		
		for (int i = 0; i < g_testEntries.length; ++i)
		{
			if (imguiItem(g_testEntries[i].name))
			{
				BGE.settings.pauseEvo = false;
				testSelection = i;
				entry         = &g_testEntries[i];
				BGE.sampleReady = false;
				test          = entry.createFcn();
				ui.chooseTest = false;
			}
		}
		
		imguiEndScrollArea();
	}
	
	imguiEndFrame();
}

import network.network;
import main;


void render()
{
//	if (BGE is null)
//	{
//		assert(0, "Missing BG thread!");
//	}
	g_debugDraw = new DebugDraw();
	g_camera.m_width  = winSize.width;
	g_camera.m_height = winSize.height;
	
	auto res = glfwInit();
	enforce(res, format("glfwInit call failed with return code: '%s'", res));
	scope(exit)
		glfwTerminate();
	
	char[64] title;
	sprintf(title.ptr, "dbox Test Version %d.%d.%d", b2_version.major, b2_version.minor, b2_version.revision);
	
	auto window = createWindow("Neural Network testbed", WindowMode.windowed, winSize.width, winSize.height);
	mainWindow = window.window;
	
	if (mainWindow is null)
	{
		fprintf(stderr.getFP(), "Failed to open GLFW mainWindow.\n");
		glfwTerminate();
		assert(0);
	}
	
	glfwMakeContextCurrent(mainWindow);
	
	// Load all OpenGL function pointers via glad.
	enforce(gladLoadGL());
	
	// printf("OpenGL %s, GLSL %s\n", glGetString(GL_VERSION), glGetString(GL_SHADING_LANGUAGE_VERSION));
	
	glfwSetScrollCallback(mainWindow, &sScrollCallback);
	glfwSetWindowSizeCallback(mainWindow, &sResizeWindow);
	glfwSetKeyCallback(mainWindow, &sKeyCallback);
	glfwSetMouseButtonCallback(mainWindow, &sMouseButton);
	glfwSetCursorPosCallback(mainWindow, &sMouseMotion);
	glfwSetScrollCallback(mainWindow, &sScrollCallback);
	
	g_debugDraw.Create();

	sCreateUI();

	testIndex = g_testEntries.countUntil!(a => a.name.toLower == entryTestName.toLower);
	if (testIndex == -1)
		testIndex = 0;

	import main : evolutionThread;
	evolutionThread.start();

	testSelection = testIndex;
	entry = &g_testEntries[testIndex];
	test = entry.createFcn();
	test.settings = &settings;

	// Control the frame rate. One draw per monitor refresh.
	glfwSwapInterval(1);

	glClearColor(1f, 1f, 1f, 1f);

	double time1     = glfwGetTime();
	double frameTime = 0.0;

	while (!glfwWindowShouldClose(mainWindow))
	{
		drawTime.start;
		glfwGetWindowSize(mainWindow, &g_camera.m_width, &g_camera.m_height);
		glViewport(0, 0, g_camera.m_width, g_camera.m_height);
		
		glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
		
		ubyte mousebutton = 0;
		int mscroll = ui.scroll;
		ui.scroll = 0;
		
		double xd, yd;
		glfwGetCursorPos(mainWindow, &xd, &yd);
		int mousex = cast(int)xd;
		int mousey = cast(int)yd;
		
		mousey = g_camera.m_height - mousey;
		int leftButton = glfwGetMouseButton(mainWindow, GLFW_MOUSE_BUTTON_LEFT);
		
		if (leftButton == GLFW_PRESS)
			mousebutton |= MouseButton.left;
		
		imguiBeginFrame(mousex, mousey, mousebutton, mscroll);
	
		sSimulate();
		sInterface();

		drawTime.stop;
		// Measure speed
		double time2 = glfwGetTime();
		double alpha = 0.9f;
		frameTime = alpha * frameTime + (1.0 - alpha) * (time2 - time1);
		time1     = time2;
		dur = drawTime.peek.hnsecs / 10000f;
		drawTime.reset;
	

		char[32] buffer = 0;
		snprintf(buffer.ptr, 32, "%.1f ms",(1000.0 * frameTime));
		addGfxCmdText(5, 5, TextAlign.left, buffer, BLACK);

		
		glEnable(GL_BLEND);
		glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
		glDisable(GL_DEPTH_TEST);
		imguiRender(g_camera.m_width, g_camera.m_height);

		glfwSwapBuffers(mainWindow);

		glfwPollEvents();
	}
	g_debugDraw.Destroy();
	imguiDestroy();
}
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
module tests.test_entries;

import framework.test;

import tests.dpercept;
import tests.pathfinder;
import tests.hindsight;
import tests.junction;
import tests.pointer;
import tests.chemotaxi;
import tests.homerun;
import tests.stresstest;
import tests.chemotaxistereo;
import tests.catcher;
import tests.spotter;
import tests.klinotaxi;
import tests.pathing;
import std.stdio;

TestEntry[] g_testEntries;

enum mode { cpu, render, user }

static this()
{
    g_testEntries =
    [
		TestEntry("Pathing", &Pathing!(mode.render).Create, &Pathing!(mode.cpu).Create, &Pathing!(mode.cpu).createSpawns,&Pathing!(mode.cpu).getNetConf),
		TestEntry("TED", &DPercept!(mode.render).Create, &DPercept!(mode.cpu).Create, &DPercept!(mode.cpu).createSpawns, &DPercept!(mode.cpu).getNetConf),
		TestEntry("Chemotaxi - Mono", &Chemotaxi!(mode.render).Create, &Chemotaxi!(mode.cpu).Create, &Chemotaxi!(mode.cpu).createSpawns,&Chemotaxi!(mode.cpu).getNetConf),
		TestEntry("Chemotaxi - Experiment", &Klinotaxi!(mode.render).Create, &Klinotaxi!(mode.cpu).Create, &Klinotaxi!(mode.cpu).createSpawns,&Klinotaxi!(mode.cpu).getNetConf),
//		TestEntry("StressTest", &Stress!(mode.render).Create, &Stress!(mode.cpu).Create, &Stress!(mode.cpu).createSpawns, &Stress!(mode.cpu).getNetConf),
//		TestEntry("Chemotaxi - Stereo", &ChemotaxiB!(mode.render).Create, &ChemotaxiB!(mode.cpu).Create, &ChemotaxiB!(mode.cpu).createSpawns,&ChemotaxiB!(mode.cpu).getNetConf),
		TestEntry("Spotter", &Spotter!(mode.render).Create, &Spotter!(mode.cpu).Create, &Spotter!(mode.cpu).createSpawns, &Spotter!(mode.cpu).getNetConf),
//		TestEntry("Ball catcher", &Catcher!(mode.render).Create, &Catcher!(mode.cpu).Create, &Catcher!(mode.cpu).createSpawns, &Catcher!(mode.cpu).getNetConf),
		TestEntry("Blind Pathfinder", &Pathfinder!(mode.render).Create, &Pathfinder!(mode.cpu).Create, &Pathfinder!(mode.cpu).createSpawns, &Pathfinder!(mode.cpu).getNetConf),
		TestEntry("Junction", &Junction!(mode.render).Create, &Junction!(mode.cpu).Create, &Junction!(mode.cpu).createSpawns, &Junction!(mode.cpu).getNetConf),
		TestEntry("Hindsight", &Hindsight!(mode.render).Create, &Hindsight!(mode.cpu).Create, &Hindsight!(mode.cpu).createSpawns, &Hindsight!(mode.cpu).getNetConf),
		TestEntry("Pointer", &Pointer!(mode.render).Create, &Pointer!(mode.cpu).Create, &Pointer!(mode.cpu).createSpawns, &Pointer!(mode.cpu).getNetConf),
		TestEntry("Homerun", &Homerun!(mode.render).Create, &Homerun!(mode.cpu).Create, &Homerun!(mode.cpu).createSpawns, &Homerun!(mode.cpu).getNetConf),
    ];

    import std.algorithm;
   // sort!((a, b) => a.name < b.name)(g_testEntries);
}

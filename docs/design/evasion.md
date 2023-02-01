Evasion Revamped
================

The current system (v0.3.0) uses Agility for both to-hit and evasion. This is an attempt to design a better way to model the actors's evasion. 

## Problem with Agility for Evasion

Actors with high to-hit will always have high evasion, causing lots of misses which in turns makes the combat drag for too long.

Many games (tabletop and video) have a lot of misses during combat, but in the wise words of Ryan Prior, "missing too much feels like gambling". Picture yourself in a casino in Las Vegas. You loaded all your coins in that one blinking slot machine and you just pull the level, over and over again. Most of the times, the vast majority of the times in fact, nothing happens. You just repeat the action until you hit that one lucky roll and take home the the jackpot. Your strategic brain is completely disengaged and you just blindly replay the same strategy (swing my favourite sword) without considering the needs of the situation

Because we want to keep the Revengate players engaged, we are redesigning combats to make misses infrequent.

How many misses during the typical encounter is too many? It's a question that can only be answered with play testing, but intuitively it should be way below 50%.


## Actors Modeling, desired behavior
Here are a few examples of what some actors should feel like. We are note aiming for ultimate realism, we are aiming for a set of a handful of rules that will capture well the diversity of combat dynamics from a variety of encounters.

* Rat: fast, small, misses a lot, hard to hit
* Ghost: slow, medium size, misses more than average, hard to hit
* Golem: slow, big, misses more than average, easy to hit
* Tiger: fast, medium-small, hits most of the time, hard to hit
* Desert Centipede: fast, medium-small, hits most of the time
* Monk without armor: fast, hits most of the time, hard to hit
* Knight in full plate: slow, hits most of the time, easy to hit
* Guard with halberd: slow, hits most of the time, hard to hit


## Actors Modeling, current
With `agility` on both sides of the to-hit roll, this is what we get.

* Rat: high agility, hits too often
* Ghost: high agility, hits too often
* Golem: low agility, feels about right
* Tiger: high agility, feels about right
* Desert Centipede: high agility, feels about right
* Monk without armor: high agility, feels about right
* Knight in full plate: low agility, misses too much
* Guard with halberd: high agility, feels about right

Some actors are very easy to model, some are almost impossible to fit in.


## Possible Solutions
There are two obvious possible solutions:

1) a new evasion core stat: actors have a new evasion stat, to-hit becomes the attacker's Agility against the victim's Evasion;

2) a new to-hit skill: to-hit becomes a roll with your weapon proficiency as bonus to your agility. You get better overtime. Beasts have high proficiency with their body parts (innate attacks). Skills can be open ended [0..inf) or in a small closed range (untrained, novice, expert). The latter translates much better into a skill tree (ex.: you can unlock rapiers *or* sabers after you become novice with blades).


## Actor Modeling, separate evasion core stat

* Rat: medium agility, high evasion, feels about right
* Ghost: medium-low agility, very high evasion, feels great!
* Golem: medium-low agility, low evasion, feels great!
* Tiger: high agility, high evasion, feels great!
* Desert Centipede: high agility, high evasion, feels about right
* Monk without armor: high agility, high evasion, feels great!
* Knight in full plate: high agility, low evasion, feels about right
* Guard with halberd: medium agility, high evasion, feels right, but we are obviously twisting the definition of the stats

Things are definitely easier to model with this system and we only introduce a small amount of extra complexity.


## Actor Modeling, to-hit skill test

* Rat: high agility, small to-hit penalty on bite attacks, works, but we are definitely twisting the definition of the stats.
* Ghost: high agility, big to-hit bonus on touch attacks, feels about right.
* Golem: low agility, big to-hit bonus on fist attacks, feels about right.
* Tiger: high agility, small to-hit bonus on claw and bite attacks, feels about right.
* Desert Centipede: high agility, small to-hit bonus on poison bite attacks, feels about right.
* Monk without armor: high agility, small to-hit bonus on punch attacks, feels great!
Knight in full plate: low agility, high to-hit bonus with trained melee weapons, feels great!
* Guard with halberd: medium-high agility, high to-hit bonus with pole arms, feels great!

This system does not quite capture all the cases, but it does model skills that should improve with usage very well. It also offers some feedback to the player in terms of character progression.


## Conclusion

A new Evasion stat is an OK quick fix, but going for trainable skills sound like a better long term solution. It's also possible to combine both systems, but the added cognitive load imposed on the player trying to plan his/her next move might not be worth the improved realism our the combined modeling.
